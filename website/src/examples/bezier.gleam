import paint as p

pub fn bezier_example() -> p.Picture {
  p.bezier(#(-50.0, -50.0), #(0.0, -50.0), #(0.0, 50.0), #(50.0, 50.0))
}
