import SceneKit
import UIKit
import UniformTypeIdentifiers
import simd
import GLTFKit2

/// Finds and loads externally made 3D character models (.usdz / .glb / .gltf / .scn).
///
/// Lookup order for fighter `id`:
///   1. Documents/Models/<id>.<ext>   (imported on device from the Files app)
///   2. App bundle  Models/<id>.<ext> (shipped with the build)
@MainActor
enum ModelLibrary {
    static let extensions = ["usdz", "glb", "gltf", "scn", "usda", "usdc"]
    private static var gltfCache: [URL: GLTFAsset] = [:]

    static var userDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func url(for id: String) -> URL? {
        for ext in extensions {
            let u = userDir.appendingPathComponent("\(id).\(ext)")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        for ext in extensions {
            if let u = Bundle.main.url(forResource: id, withExtension: ext, subdirectory: "Models") { return u }
        }
        return nil
    }

    static func hasModel(_ id: String) -> Bool { url(for: id) != nil }
    static func isUserImported(_ id: String) -> Bool { url(for: id)?.path.hasPrefix(userDir.path) ?? false }

    /// Optional per-model settings: Models/<id>.json  {"yaw": 180, "height": 2.1}
    static func settings(for id: String) -> [String: Double] {
        let candidates = [userDir.appendingPathComponent("\(id).json"),
                          Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "Models")].compactMap { $0 }
        for u in candidates {
            if let d = try? Data(contentsOf: u), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Double] { return obj }
        }
        return [:]
    }

    /// Loads the model into a fresh container node (every call returns independent nodes).
    static func load(_ url: URL) -> SCNNode? {
        let container = SCNNode()
        let ext = url.pathExtension.lowercased()
        var sceneRoot: SCNNode?
        if ext == "glb" || ext == "gltf" {
            let asset: GLTFAsset?
            if let cached = gltfCache[url] {
                asset = cached
            } else {
                asset = try? GLTFAsset(url: url, options: [:])
                if let asset { gltfCache[url] = asset }
            }
            guard let asset else { return nil }
            let source = GLTFSCNSceneSource(asset: asset)
            sceneRoot = source.defaultScene?.rootNode ?? source.scenes.first?.rootNode
        } else {
            sceneRoot = (try? SCNScene(url: url, options: [.checkConsistency: false]))?.rootNode
        }
        guard let root = sceneRoot else { return nil }
        for child in root.childNodes {
            child.removeFromParentNode()
            container.addChildNode(child)
        }
        // We drive the skeleton ourselves; drop baked animations, lights and cameras.
        container.enumerateHierarchy { n, _ in
            n.removeAllAnimations()
            n.light = nil
            n.camera = nil
        }
        return container
    }

    static func importFile(from src: URL, for id: String) throws {
        let ext = src.pathExtension.lowercased()
        guard extensions.contains(ext) else {
            throw NSError(domain: "MoonAction", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type .\(ext)"])
        }
        remove(id)
        let dst = userDir.appendingPathComponent("\(id).\(ext)")
        let scoped = src.startAccessingSecurityScopedResource()
        defer { if scoped { src.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: src, to: dst)
        gltfCache.removeValue(forKey: dst)
        Portraits.invalidate(id)
    }

    static func remove(_ id: String) {
        for ext in extensions {
            let u = userDir.appendingPathComponent("\(id).\(ext)")
            try? FileManager.default.removeItem(at: u)
            gltfCache.removeValue(forKey: u)
        }
        Portraits.invalidate(id)
    }

    static var contentTypes: [UTType] {
        var t: [UTType] = [.usdz, .sceneKitScene]
        for ext in ["glb", "gltf", "usda", "usdc"] {
            if let u = UTType(filenameExtension: ext) { t.append(u) }
        }
        return t
    }
}

/// Maps an imported humanoid skeleton onto the game's joints and retargets the
/// procedurally animated poses onto it every frame (works with Mixamo, AccuRIG,
/// VRM/Unity-style and Blender ".L/.R" naming, in T-pose or A-pose).
@MainActor
final class Retargeter {
    private struct Link {
        let joint: Joint
        let bone: SCNNode
        let bind: simd_quatf          // bind orientation in container space
        let correction: simd_quatf    // rotates the imported rest direction onto the game's rest direction
    }

    private let container: SCNNode
    private var links: [Link] = []
    private(set) var handR: SCNNode?
    private(set) var handL: SCNNode?
    private(set) var head: SCNNode?
    var isValid: Bool { links.count >= 6 }
    var mappedCount: Int { links.count }

    private static let names: [String: [String]] = [
        "spine": ["spine1", "spine01", "spine2", "chest", "spine", "upperchest", "ccbasespine01"],
        "neck": ["neck", "neck1", "ccbaseneck"],
        "head": ["head", "ccbasehead"],
        "shoulderL": ["leftarm", "leftupperarm", "upperarml", "upperarmleft", "luparm", "lupperarm", "ccbaselupperarm", "arml"],
        "elbowL": ["leftforearm", "leftlowerarm", "forearml", "lowerarml", "lforearm", "ccbaselforearm"],
        "handL": ["lefthand", "handl", "lhand", "ccbaselhand"],
        "shoulderR": ["rightarm", "rightupperarm", "upperarmr", "upperarmright", "ruparm", "rupperarm", "ccbaserupperarm", "armr"],
        "elbowR": ["rightforearm", "rightlowerarm", "forearmr", "lowerarmr", "rforearm", "ccbaserforearm"],
        "handR": ["righthand", "handr", "rhand", "ccbaserhand"],
        "hipL": ["leftupleg", "leftupperleg", "thighl", "upperlegl", "lthigh", "leftthigh", "ccbaselthigh"],
        "kneeL": ["leftleg", "leftlowerleg", "calfl", "lowerlegl", "shinl", "lcalf", "leftshin", "ccbaselcalf"],
        "footL": ["leftfoot", "footl", "lfoot", "ccbaselfoot"],
        "hipR": ["rightupleg", "rightupperleg", "thighr", "upperlegr", "rthigh", "rightthigh", "ccbaserthigh"],
        "kneeR": ["rightleg", "rightlowerleg", "calfr", "lowerlegr", "shinr", "rcalf", "rightshin", "ccbasercalf"],
        "footR": ["rightfoot", "footr", "rfoot", "ccbaserfoot"],
    ]

    static func normalize(_ s: String) -> String {
        var n = s
        if let r = n.range(of: ":", options: .backwards) { n = String(n[r.upperBound...]) }
        if let r = n.range(of: "|", options: .backwards) { n = String(n[r.upperBound...]) }
        n = n.lowercased().replacingOccurrences(of: "mixamorig", with: "")
        return n.filter { $0.isLetter || $0.isNumber }
    }

    init(container: SCNNode) {
        self.container = container
        var byName: [String: SCNNode] = [:]
        container.enumerateHierarchy { n, _ in
            guard let name = n.name, n.geometry == nil else { return }
            let k = Retargeter.normalize(name)
            if byName[k] == nil { byName[k] = n }
        }
        func find(_ key: String) -> SCNNode? {
            for cand in Retargeter.names[key] ?? [] { if let n = byName[cand] { return n } }
            return nil
        }
        let restDown = SIMD3<Float>(0, -1, 0)
        let restUp = SIMD3<Float>(0, 1, 0)
        let pairs: [(Joint, String, String?, SIMD3<Float>?)] = [
            (.spine, "spine", "neck", restUp), (.head, "head", nil, nil),
            (.shoulderL, "shoulderL", "elbowL", restDown), (.elbowL, "elbowL", "handL", restDown),
            (.shoulderR, "shoulderR", "elbowR", restDown), (.elbowR, "elbowR", "handR", restDown),
            (.hipL, "hipL", "kneeL", restDown), (.kneeL, "kneeL", "footL", restDown),
            (.hipR, "hipR", "kneeR", restDown), (.kneeR, "kneeR", "footR", restDown),
        ]
        for (joint, key, childKey, rest) in pairs {
            guard let bone = find(key) else { continue }
            let bind = Retargeter.orientation(of: bone, in: container)
            var corr = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
            if let rest, let ck = childKey, let child = find(ck) ?? (key == "spine" ? find("head") : nil) {
                let a = Retargeter.position(of: bone, in: container)
                let b = Retargeter.position(of: child, in: container)
                let d = b - a
                if simd_length(d) > 1e-4 { corr = simd_quatf(from: simd_normalize(d), to: rest) }
            }
            links.append(Link(joint: joint, bone: bone, bind: bind, correction: corr))
        }
        handR = find("handR")
        handL = find("handL")
        head = find("head")
    }

    private static func position(of n: SCNNode, in c: SCNNode) -> SIMD3<Float> {
        n.simdConvertPosition(.zero, to: c)
    }

    private static func orientation(of n: SCNNode, in c: SCNNode) -> simd_quatf {
        let m = n.simdConvertTransform(matrix_identity_float4x4, to: c)
        let x = simd_normalize(SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z))
        let y = simd_normalize(SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z))
        let z = simd_normalize(SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z))
        return simd_quatf(simd_float3x3(x, y, z))
    }

    /// Copies the rig's current pose (joint rotations relative to `reference`) onto the imported bones.
    func sync(joints: [Joint: SCNNode], reference: SCNNode) {
        let refInv = reference.simdWorldOrientation.inverse
        let cInv = container.simdWorldOrientation.inverse
        for l in links {
            guard let j = joints[l.joint], let parent = l.bone.parent else { continue }
            let delta = refInv * j.simdWorldOrientation
            let desired = delta * l.correction * l.bind
            let parentOri = cInv * parent.simdWorldOrientation
            l.bone.simdOrientation = parentOri.inverse * desired
        }
    }
}

/// Presents the Files picker and imports a model for a fighter.
@MainActor
final class ModelPicker: NSObject, UIDocumentPickerDelegate {
    private static var current: ModelPicker?
    private let id: String
    private let done: (Result<Void, Error>) -> Void

    private init(id: String, done: @escaping (Result<Void, Error>) -> Void) {
        self.id = id
        self.done = done
    }

    static func present(from vc: UIViewController, for id: String, done: @escaping (Result<Void, Error>) -> Void) {
        let p = ModelPicker(id: id, done: done)
        current = p
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: ModelLibrary.contentTypes, asCopy: true)
        picker.delegate = p
        picker.allowsMultipleSelection = false
        vc.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let u = urls.first else { return }
        do {
            try ModelLibrary.importFile(from: u, for: id)
            done(.success(()))
        } catch {
            done(.failure(error))
        }
        ModelPicker.current = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        ModelPicker.current = nil
    }
}
