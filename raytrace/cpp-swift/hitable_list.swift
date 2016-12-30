struct hitable_list: Hitable {
    init(_ l: [sphere]) { list = l }
    func hit(_ r: ray, _ t_min: Double, _ t_max: Double) -> hit_record? {
        var temp_rec: hit_record?
        var closest_so_far = t_max
        for element in list {
            if let rec = element.hit(r, t_min, closest_so_far) {
                closest_so_far = rec.t;
                temp_rec = rec
            }
        }
        return temp_rec
    }
    let list: [sphere]
}
