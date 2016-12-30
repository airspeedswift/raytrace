struct hit_record {
    var t: Double;
    var p: vec3;
    var normal: vec3;
    var mat_ptr: material;
}

protocol Hitable {
    func hit(_ r: ray, _ t_min: Double, _ t_max: Double) -> hit_record?
}
