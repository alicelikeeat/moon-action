import SceneKit
import simd

/// MeshKit — a small procedural modeling system.
/// Builds smooth, skinned (bone-weighted) meshes from lofted cross-sections, deformable
/// ellipsoids and Bézier hair strands, then outputs a single SceneKit geometry with one
/// element per material slot, an `SCNSkinner`, and an inverted-hull outline mesh.
@MainActor
final class MeshBuilder {
    struct Vertex {
        var p: SIMD3<Float>
        var n: SIMD3<Float>
        var b: SIMD2<UInt16>
        var w: SIMD2<Float>
    }

    /// A bone influence: (bone A, bone B, weight of B).
    struct Bind {
        var a: UInt16
        var b: UInt16
        var t: Float
        init(_ a: Int, _ b: Int? = nil, _ t: Float = 0) {
            self.a = UInt16(a)
            self.b = UInt16(b ?? a)
            self.t = b == nil ? 0 : t
        }
    }

    private(set) var verts: [Vertex] = []
    private(set) var slots: [Int: [UInt32]] = [:]
    private var noOutline: Set<Int> = []

    func disableOutline(slot: Int) { noOutline.insert(slot) }

    private func addVertex(_ p: SIMD3<Float>, _ n: SIMD3<Float>, _ bind: Bind) -> UInt32 {
        verts.append(Vertex(p: p, n: n, b: SIMD2(bind.a, bind.b), w: SIMD2(1 - bind.t, bind.t)))
        return UInt32(verts.count - 1)
    }

    /// Adds a triangle, fixing winding so its face normal agrees with the vertices' outward normals.
    private func tri(_ a: UInt32, _ b: UInt32, _ c: UInt32, slot: Int) {
        let pa = verts[Int(a)].p, pb = verts[Int(b)].p, pc = verts[Int(c)].p
        let fn = simd_cross(pb - pa, pc - pa)
        let out = verts[Int(a)].n + verts[Int(b)].n + verts[Int(c)].n
        if simd_dot(fn, out) >= 0 {
            slots[slot, default: []] += [a, b, c]
        } else {
            slots[slot, default: []] += [a, c, b]
        }
    }

    // MARK: Frames

    private static func frame(tangent t: SIMD3<Float>, ref: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>) {
        var r = ref - simd_dot(ref, t) * t
        if simd_length(r) < 1e-3 {
            let alt: SIMD3<Float> = abs(t.x) < 0.9 ? SIMD3(1, 0, 0) : SIMD3(0, 0, 1)
            r = alt - simd_dot(alt, t) * t
        }
        let z = simd_normalize(r)
        let x = simd_normalize(simd_cross(t, z))
        return (x, z)
    }

    // MARK: Primitives

    /// Lofted tube through `path` with elliptical sections (rx along side axis, rz along `ref` axis).
    func loft(path: [SIMD3<Float>], radii: [SIMD2<Float>], binds: [Bind], slots ringSlots: [Int],
              sides: Int = 14, ref: SIMD3<Float> = SIMD3(0, 0, 1), capStart: Bool = false, capEnd: Bool = false,
              offsets: [SIMD2<Float>]? = nil) {
        let n = path.count
        guard n >= 2 else { return }
        var rings: [[UInt32]] = []
        var prevZ: SIMD3<Float>?
        for i in 0..<n {
            let t0 = i == 0 ? path[1] - path[0] : (i == n - 1 ? path[n - 1] - path[n - 2] : path[i + 1] - path[i - 1])
            let t = simd_normalize(t0)
            var (x, z) = MeshBuilder.frame(tangent: t, ref: prevZ ?? ref)
            if prevZ == nil { (x, z) = MeshBuilder.frame(tangent: t, ref: ref) }
            prevZ = z
            let r = radii[i]
            let off = offsets?[i] ?? .zero
            let center = path[i] + x * off.x + z * off.y
            var ring: [UInt32] = []
            for j in 0..<sides {
                let a = Float(j) / Float(sides) * 2 * .pi
                let p = center + x * (cos(a) * r.x) + z * (sin(a) * r.y)
                let nrm = simd_normalize(x * (cos(a) / max(r.x, 1e-4)) + z * (sin(a) / max(r.y, 1e-4)))
                ring.append(addVertex(p, nrm, binds[i]))
            }
            rings.append(ring)
        }
        for i in 0..<(n - 1) {
            let s = ringSlots[min(i, ringSlots.count - 1)]
            for j in 0..<sides {
                let j2 = (j + 1) % sides
                tri(rings[i][j], rings[i + 1][j], rings[i + 1][j2], slot: s)
                tri(rings[i][j], rings[i + 1][j2], rings[i][j2], slot: s)
            }
        }
        if capStart { cap(ring: rings[0], center: path[0], normal: simd_normalize(path[0] - path[1]), bind: binds[0], slot: ringSlots[0]) }
        if capEnd {
            cap(ring: rings[n - 1], center: path[n - 1], normal: simd_normalize(path[n - 1] - path[n - 2]),
                bind: binds[n - 1], slot: ringSlots[min(n - 2, ringSlots.count - 1)])
        }
    }

    private func cap(ring: [UInt32], center: SIMD3<Float>, normal: SIMD3<Float>, bind: Bind, slot: Int) {
        let c = addVertex(center, normal, bind)
        for j in 0..<ring.count {
            let a = ring[j], b = ring[(j + 1) % ring.count]
            // Use the cap normal for winding
            let pa = verts[Int(a)].p, pb = verts[Int(b)].p, pc = verts[Int(c)].p
            let fn = simd_cross(pb - pa, pc - pa)
            if simd_dot(fn, normal) >= 0 { slots[slot, default: []] += [a, b, c] } else { slots[slot, default: []] += [a, c, b] }
        }
    }

    /// Ellipsoid with optional deformation applied to unit-sphere coordinates.
    func ellipsoid(center: SIMD3<Float>, radii: SIMD3<Float>, bind: Bind, slot: Int, rings: Int = 12, sides: Int = 16,
                   rotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0)),
                   deform: ((SIMD3<Float>) -> SIMD3<Float>)? = nil) {
        var grid: [[UInt32]] = []
        for i in 0...rings {
            let v = Float(i) / Float(rings)
            let lat = -Float.pi / 2 + v * .pi
            var row: [UInt32] = []
            for j in 0...sides {
                let u = Float(j) / Float(sides) * 2 * .pi
                var unit = SIMD3<Float>(cos(lat) * sin(u), sin(lat), cos(lat) * cos(u))
                if let deform { unit = deform(unit) }
                let local = unit * radii
                let p = center + rotation.act(local)
                let nrm = simd_normalize(rotation.act(unit / radii))
                row.append(addVertex(p, nrm, bind))
            }
            grid.append(row)
        }
        for i in 0..<rings {
            for j in 0..<sides {
                let a = grid[i][j], b = grid[i + 1][j], c = grid[i + 1][j + 1], d = grid[i][j + 1]
                if i != 0 { tri(a, b, c, slot: slot) } else { tri(a, b, c, slot: slot) }
                tri(a, c, d, slot: slot)
            }
        }
    }

    /// Tapered, slightly flattened strand along a cubic Bézier (anime hair locks, scarf tails…).
    func strand(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>, _ p2: SIMD3<Float>, _ p3: SIMD3<Float>,
                width: Float, flatten: Float = 0.6, taper: Float = 1, bind: Bind, slot: Int,
                segments: Int = 7, sides: Int = 6, ref: SIMD3<Float>) {
        var path: [SIMD3<Float>] = []
        var radii: [SIMD2<Float>] = []
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            let mt = 1 - t
            let p = mt * mt * mt * p0 + 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t * p3
            path.append(p)
            let r = width * max(0.02, 1 - taper * pow(t, 1.15))
            radii.append(SIMD2(r, r * flatten))
        }
        loft(path: path, radii: radii, binds: Array(repeating: bind, count: path.count),
             slots: [slot], sides: sides, ref: ref, capStart: true)
    }

    // MARK: Output

    private func recomputeNormals() {
        var acc = [SIMD3<Float>](repeating: .zero, count: verts.count)
        for (_, idx) in slots {
            var k = 0
            while k + 2 < idx.count {
                let a = Int(idx[k]), b = Int(idx[k + 1]), c = Int(idx[k + 2])
                let fn = simd_cross(verts[b].p - verts[a].p, verts[c].p - verts[a].p)
                acc[a] += fn
                acc[b] += fn
                acc[c] += fn
                k += 3
            }
        }
        for i in 0..<verts.count where simd_length(acc[i]) > 1e-9 {
            verts[i].n = simd_normalize(acc[i])
        }
    }

    private func sources(offset: Float) -> [SCNGeometrySource] {
        let positions = verts.map { v -> SCNVector3 in
            let p = v.p + v.n * offset
            return SCNVector3(p.x, p.y, p.z)
        }
        let normals = verts.map { SCNVector3($0.n.x, $0.n.y, $0.n.z) }
        return [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)]
    }

    private func skinSources() -> (SCNGeometrySource, SCNGeometrySource) {
        var weights: [Float] = []
        var indices: [UInt16] = []
        weights.reserveCapacity(verts.count * 2)
        indices.reserveCapacity(verts.count * 2)
        for v in verts {
            weights += [v.w.x, v.w.y]
            indices += [v.b.x, v.b.y]
        }
        let wData = weights.withUnsafeBufferPointer { Data(buffer: $0) }
        let iData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let w = SCNGeometrySource(data: wData, semantic: .boneWeights, vectorCount: verts.count, usesFloatComponents: true,
                                  componentsPerVector: 2, bytesPerComponent: 4, dataOffset: 0, dataStride: 8)
        let i = SCNGeometrySource(data: iData, semantic: .boneIndices, vectorCount: verts.count, usesFloatComponents: false,
                                  componentsPerVector: 2, bytesPerComponent: 2, dataOffset: 0, dataStride: 4)
        return (w, i)
    }

    /// Builds the skinned mesh + its outline hull, both bound to `bones` under `skeleton`.
    /// Vertex positions must be expressed in `skeleton` space at bind pose.
    func buildSkinned(bones: [SCNNode], skeleton: SCNNode, materials: [Int: SCNMaterial], outline: SCNMaterial,
                      outlineWidth: Float) -> (mesh: SCNNode, hull: SCNNode) {
        recomputeNormals()
        let keys = slots.keys.sorted()
        let elements = keys.map { SCNGeometryElement(indices: slots[$0]!, primitiveType: .triangles) }
        let geo = SCNGeometry(sources: sources(offset: 0), elements: elements)
        geo.materials = keys.map { materials[$0] ?? SCNMaterial() }

        var hullIdx: [UInt32] = []
        for k in keys where !noOutline.contains(k) { hullIdx += slots[k]! }
        let hullGeo = SCNGeometry(sources: sources(offset: outlineWidth),
                                  elements: [SCNGeometryElement(indices: hullIdx, primitiveType: .triangles)])
        hullGeo.materials = [outline]

        let inv: [NSValue] = bones.map { b in
            let m = b.simdConvertTransform(matrix_identity_float4x4, to: skeleton)
            return NSValue(scnMatrix4: SCNMatrix4(m.inverse))
        }
        let (w, i) = skinSources()
        let mesh = SCNNode(geometry: geo)
        let skin = SCNSkinner(baseGeometry: geo, bones: bones, boneInverseBindTransforms: inv, boneWeights: w, boneIndices: i)
        skin.skeleton = skeleton
        mesh.skinner = skin

        let hull = SCNNode(geometry: hullGeo)
        let hskin = SCNSkinner(baseGeometry: hullGeo, bones: bones, boneInverseBindTransforms: inv, boneWeights: w, boneIndices: i)
        hskin.skeleton = skeleton
        hull.skinner = hskin
        return (mesh, hull)
    }
}
