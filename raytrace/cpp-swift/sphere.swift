import Darwin

struct sphere: Hitable {
    init(_ cen: vec3, _ r: Double, _ m: @escaping material) { center = cen; radius = r; mat_ptr = m }
    func hit(_ r: ray, _ t_min: Double, _ t_max: Double) -> hit_record? {
        let oc = r.origin - center;

        let a = dot(r.direction, r.direction);
        let b = dot(oc, r.direction);
        let c = dot(oc, oc) - radius*radius;
        let discriminant = b*b - a*c;
        if (discriminant > 0) {
            var temp = (-b - sqrt(b*b-a*c))/a;
            let p = r.point_at_parameter(temp)
            if (temp < t_max && temp > t_min) {
                return hit_record(
                  t: temp,
                  p: p,
                  normal: (p - center) / radius,
                  mat_ptr: mat_ptr)
            }
            temp = (-b + sqrt(b*b-a*c))/a;
            if (temp < t_max && temp > t_min) {
                return hit_record(
                    t: temp,
                    p: p,
                    normal: (p - center) / radius,
                    mat_ptr: mat_ptr)
            }
        }
        return nil
    }
    let center: vec3;
    let radius: Double;
    let mat_ptr: material;
}
