//
//  main.swift
//  raytrace
//
//  Created by Rob Napier on 12/23/16.
//
//

import Foundation

public struct StderrOutputStream: TextOutputStream {
    public mutating func write(_ string: String) {
        fputs(string, stderr)}
}
public var errStream = StderrOutputStream()

func errPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    for item in items {
        print(item, separator, terminator: "", to: &errStream)
    }
    print(terminator, terminator: "", to: &errStream)
}

infix operator ⋅ : MultiplicationPrecedence
infix operator × : MultiplicationPrecedence

func schlick(cosine: Double, ri: Double) -> Double {
    var r0 = (1-ri)/(1+ri)
    r0 = r0*r0
    return r0 + (1-r0)*pow((1-cosine), 5)
}

struct Vector {
    static var zero: Vector { return Vector(0, 0, 0) }
    static func *(scalar: Double, rhs: Vector) -> Vector {
        return Vector(scalar * rhs.x, scalar * rhs.y, scalar * rhs.z)
    }
    static func *(rhs: Vector, scalar: Double) -> Vector {
        return Vector(scalar * rhs.x, scalar * rhs.y, scalar * rhs.z)
    }
    static prefix func -(v: Vector) -> Vector {
        return Vector(-v.x, -v.y, -v.z)
    }

    static func /(lhs: Vector, scalar: Double) -> Vector {
        return Vector(lhs.x / scalar, lhs.y / scalar, lhs.z / scalar)
    }

    func lerp(to: Vector, at t: Double) -> Vector {
        return (1.0 - t) * self + t * to
    }

    var x, y, z: Double
    init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    var length: Double {
        return sqrt(lengthSquared)
    }

    var lengthSquared: Double {
        return x*x + y*y + z*z
    }

    var unit: Vector {
        return self / length
    }

    static func +(lhs: Vector, rhs: Vector) -> Vector {
        return Vector(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func +=(lhs: inout Vector, rhs: Vector) {
        lhs = Vector(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func -(lhs: Vector, rhs: Vector) -> Vector {
        return Vector(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func *(lhs: Vector, rhs: Vector) -> Vector {
        return Vector(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
    }

    static func ⋅(lhs: Vector, rhs: Vector) -> Double {
        return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }

    static func ×(lhs: Vector, rhs: Vector) -> Vector {
        return Vector( (  lhs.y * rhs.z - lhs.z * rhs.y),
                       (-(lhs.x * rhs.z - lhs.z * rhs.x)),
                       (  lhs.x * rhs.y - lhs.y * rhs.x))
    }

    static func randomInUnitSphere() -> Vector {
        repeat {
            let p = 2.0*Vector(drand48(), drand48(), drand48()) - Vector(1,1,1)
            if p.lengthSquared < 1 { return p }
        } while true
    }

    static func randomInUnitDisk() -> Vector {
        repeat {
            let p = 2.0*Vector(drand48(), drand48(), 0) - Vector(1,1,0)
            if p⋅p < 1 { return p }
        } while true
    }

    func reflect(acrossNormal n: Vector) -> Vector {
        return self - 2*self⋅n*n
    }

    func refract(acrossNormal n: Vector, withRefractiveIndex ri: Double) -> Vector? {
        let uv = unit
        let dt = uv ⋅ n
        let discriminant = 1.0 - ri*ri*(1-dt*dt)
        if discriminant > 0 {
            return ri*(uv - n*dt) - n*sqrt(discriminant)
        } else {
            return nil
        }
    }
}

extension Vector: CustomStringConvertible {
    var description: String {
        return "(\(x),\(y),\(z))"
    }
}

struct Ray {
    let origin: Vector
    let direction: Vector
    init(origin: Vector, direction: Vector) {
        self.origin = origin
        self.direction = direction
    }
    init(origin: Vector, through: Vector) {
        self.origin = origin
        self.direction = through - origin
    }
    func point(atParameter t: Double) -> Vector {
        return origin + t * direction
    }
}

extension Ray: CustomStringConvertible {
    var description: String {
        return "[\(origin) -> \(direction)]"
    }
}

extension Vector {
    var r: Double { return x }
    var g: Double { return y }
    var b: Double { return z }
}

extension Ray {
    func color<World: Hittable>(in world: World, depth: Int = 0) -> Vector {
        if let rec = world.hitRecord(for: self, in: (0.001)..<(Double(MAXFLOAT))) {
            if depth < 50,
                let scatterResult = rec.material.scatter(ray: self, hitRecord: rec) {
                return scatterResult.attenuation * scatterResult.scattered.color(in: world, depth: depth + 1)
            } else {
                return Vector.zero
            }
        } else {
            let unitDirection = direction.unit
            let t = 0.5 * (unitDirection.y + 1)
            return Vector(1, 1, 1).lerp(to: Vector(0.5, 0.7, 1), at: t)
        }
    }
}

struct HitRecord {
    var t: Double
    var p: Vector
    var normal: Vector
    var material: Material
}

protocol Hittable {
    func hitRecord(for ray: Ray, in: Range<Double>) -> HitRecord?
}

struct Sphere<M: Material>: Hittable {
    let center: Vector
    let radius: Double
    let material: M

    init(center: Vector, radius: Double, material: M) {
        self.center = center
        self.radius = radius
        self.material = material
    }

    func hitRecord(for ray: Ray, in range: Range<Double>) -> HitRecord? {

        func hitRecord(for t: Double) -> HitRecord? {
            // Do not include ends of range
            guard t > range.lowerBound && t < range.upperBound else { return nil }
            let point = ray.point(atParameter: t)
            return HitRecord(t: t,
                             p: point,
                             normal: (point - center) / radius,
                             material: material)
        }

        let oc = ray.origin - center
        let a = ray.direction ⋅ ray.direction
        let b = oc ⋅ ray.direction
        let c = oc ⋅ oc - radius * radius
        let discriminant = b * b - a * c

        if discriminant > 0 {
            let s = sqrt(discriminant)
            return hitRecord(for: (-b - s)/a) ?? hitRecord(for: (-b + s)/a)
        }

        return nil
    }
}

struct HittableArray: Hittable {
    let elements: [Hittable]

    init(_ elements: [Hittable]) { self.elements = elements }

    func hitRecord(for ray: Ray, in range: Range<Double>) -> HitRecord? {
        var closestHit: HitRecord? = nil
        var maxT = range.upperBound
        for element in elements {
            if let hit = element.hitRecord(for: ray, in: range.lowerBound..<maxT) {
                closestHit = hit
                maxT = hit.t
            }
        }
        return closestHit
    }
}

struct Camera {
    init(lookFrom: Vector, lookAt: Vector, vup: Vector, vfov: Double, aspect: Double, aperture: Double, focusDist: Double) {
        lensRadius = aperture / 2
        let theta = vfov*M_PI/180
        let halfHeight = tan(theta/2)
        let halfWidth = aspect * halfHeight
        origin = lookFrom
        w = (lookFrom - lookAt).unit
        u = (vup × w).unit
        v = w × u
        lowerLeftCorner = origin - halfWidth*focusDist*u - halfHeight*focusDist*v - focusDist*w
        horizontal = 2*halfWidth*focusDist*u
        vertical = 2*halfHeight*focusDist*v
    }
    let lowerLeftCorner: Vector
    let horizontal: Vector
    let vertical: Vector
    let origin: Vector
    let u, v, w: Vector
    let lensRadius: Double

    func ray(atPlaneX x: Double, planeY y: Double) -> Ray {
        let rd = lensRadius*Vector.randomInUnitDisk()
        let offset = u * rd.x + v * rd.y
        return Ray(origin: origin + offset, direction: lowerLeftCorner + x * horizontal + y * vertical - origin - offset)
    }
}

struct ScatterResult {
    let scattered: Ray
    let attenuation: Vector
}

protocol Material {
    func scatter(ray: Ray, hitRecord: HitRecord) -> ScatterResult?
}

struct Lambertian: Material {
    let albedo: Vector
    func scatter(ray: Ray, hitRecord rec: HitRecord) -> ScatterResult? {
        let target = rec.p + rec.normal + Vector.randomInUnitSphere()
        return ScatterResult(scattered: Ray(origin: rec.p, direction: target - rec.p),
                             attenuation: albedo)
    }
}

struct Metal: Material {
    let albedo: Vector
    let fuzz: Double
    init(albedo: Vector, fuzz: Double) {
        self.albedo = albedo
        self.fuzz = min(fuzz, 1)
    }
    func scatter(ray: Ray, hitRecord rec: HitRecord) -> ScatterResult? {
        let reflected = ray.direction.unit.reflect(acrossNormal: rec.normal)
        let scattered = Ray(origin: rec.p, direction: reflected + fuzz*Vector.randomInUnitSphere())
        guard scattered.direction ⋅ rec.normal > 0 else { return nil }
        return ScatterResult(scattered: scattered, attenuation: albedo)
    }
}

struct Dielectric: Material {
    let refractionIndex: Double
    func scatter(ray: Ray, hitRecord rec: HitRecord) -> ScatterResult? {
        let outwardNormal: Vector
        let reflected = ray.direction.reflect(acrossNormal: rec.normal)
        let ni_over_nt: Double
        let attenuation = Vector(1,1,1)
        let cosine: Double
        if ray.direction ⋅ rec.normal > 0 {
            outwardNormal = -rec.normal
            ni_over_nt = refractionIndex
            cosine = refractionIndex * ray.direction ⋅ rec.normal / ray.direction.length
        } else {
            outwardNormal = rec.normal
            ni_over_nt = 1.0 / refractionIndex
            cosine = -ray.direction ⋅ rec.normal / ray.direction.length
        }

        let reflectProb: Double
        let refracted = ray.direction.refract(acrossNormal: outwardNormal, withRefractiveIndex: ni_over_nt)
        if refracted != nil {
            reflectProb = schlick(cosine: cosine, ri: refractionIndex)
        } else {
            reflectProb = 1.0
        }

        if drand48() < reflectProb {
            return ScatterResult(scattered: Ray(origin: rec.p, direction: reflected), attenuation: attenuation)
        } else {
            return ScatterResult(scattered: Ray(origin: rec.p, direction: refracted!), attenuation: attenuation)
        }
//        if let refracted = ray.direction.refract(acrossNormal: outwardNormal, withRefractiveIndex: ni_over_nt),
//            drand48() >= schlick(cosine: cosine, ri: refractionIndex) {
//            return ScatterResult(scattered: Ray(origin: rec.p, direction: refracted), attenuation: attenuation)
//        } else {
//            return ScatterResult(scattered: Ray(origin: rec.p, direction: reflected), attenuation: attenuation)
//        }
    }
}

func randomScene() -> HittableArray {
    var list: [Hittable] = [Sphere(center: Vector(0,-1000,0), radius: 1000, material: Lambertian(albedo: Vector(0.5,0.5,0.5)))]

    for a in -11..<11 {
        for b in -11..<11 {
            let chooseMat = drand48()
            let center = Vector(Double(a)+0.9*drand48(),0.2,Double(b)+0.9*drand48());
            if (center-Vector(4,0.2,0)).length > 0.9 {
                if (chooseMat < 0.8) { // diffuse
                    list.append(Sphere(center: center, radius: 0.2, material: Lambertian(albedo: Vector(drand48()*drand48(), drand48()*drand48(), drand48()*drand48()))))
                } else if chooseMat < 0.95 { // metal
                    list.append(Sphere(center: center, radius: 0.2, material: Metal(albedo: Vector(0.5*(1 + drand48()), 0.5*(1 + drand48()), 0.5*(1 + drand48())), fuzz: 0.5*drand48())))
                } else { // glass
                    list.append(Sphere(center: center, radius: 0.2, material: Dielectric(refractionIndex: 1.5)))
                }
            }
        }
    }

    list.append(Sphere(center: Vector(0,1,0), radius: 1.0, material: Dielectric(refractionIndex: 1.5)))
    list.append(Sphere(center: Vector(-4,1,0), radius: 1.0, material: Lambertian(albedo: Vector(0.4,0.2,0.1))))
    list.append(Sphere(center: Vector(4,1,0), radius: 1.0, material: Metal(albedo: Vector(0.7, 0.6, 0.5), fuzz: 0.0)))
    return HittableArray(list)
}

srand48(0)

let nx = 200
let ny = 100
let ns = 100

print("P3\n\(nx) \(ny)\n255")

let world = randomScene()

let lookFrom = Vector(16,2,4)
let lookAt = Vector(0,0.5,0)
let focalPoint = Vector(4,1,0)
let distToFocus = (lookFrom - focalPoint).length
let aperture = 1.0/16.0
let camera = Camera(lookFrom: lookFrom, lookAt: lookAt, vup: Vector(0,1,0), vfov: 15, aspect: Double(nx)/Double(ny), aperture: aperture, focusDist: distToFocus)

for j in (0..<ny).reversed() {
    for i in 0..<nx {
        var col = Vector.zero
        for _ in 0..<ns {
            let u = (Double(i) + drand48()) / Double(nx)
            let v = (Double(j) + drand48()) / Double(ny)
            let r = camera.ray(atPlaneX: u, planeY: v)
            col += r.color(in: world)
        }
        col = Vector(sqrt(col.x / Double(ns)), sqrt(col.y / Double(ns)), sqrt(col.z / Double(ns)))

        let ir = Int(255.99 * col.r)
        let ig = Int(255.99 * col.g)
        let ib = Int(255.99 * col.b)
        print("\(ir) \(ig) \(ib)")
    }
}
