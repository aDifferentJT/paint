import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam_community/colour
import paint.{type Picture}
import paint/internal/types.{
  type Angle, type StrokeProperties, type TextAlign, type TextBaseline,
  type TextDirection, NoStroke, Radians, SolidStroke, TextAlignCenter,
  TextAlignEnd, TextAlignLeft, TextAlignRight, TextAlignStart,
  TextBaselineAlphabetic, TextBaselineBottom, TextBaselineHanging,
  TextBaselineIdeographic, TextBaselineMiddle, TextBaselineTop,
  TextDirectionInherit, TextDirectionLtr, TextDirectionRtl,
}

/// Serialize a `Picture` to a string.
///
/// Note, serializing an `Image` texture will only store an ID referencing the image. This means that if you deserialize a Picture containing
/// references to images, you are responsible for making sure all images are loaded before drawing the picture.
/// More advanced APIs to support use cases such as these are planned for a future release.
///
/// Also, if you wish to store the serialized data, remember that the library currently makes no stability guarantee that
/// the data can be deserialized by *future* versions of the library.
pub fn to_string(picture: Picture) -> String {
  let version = "paint:unstable"
  json.object([
    #("version", json.string(version)),
    #("picture", picture_to_json(picture)),
  ])
  |> json.to_string
}

/// Attempt to deserialize a `Picture`
pub fn from_string(string: String) {
  let decoder = {
    use picture <- decode.field("picture", decode_picture())
    decode.success(picture)
  }
  json.parse(string, decoder)
}

fn decode_angle() {
  use radians <- decode.field("radians", decode.float)
  decode.success(Radians(radians))
}

fn decode_picture() -> Decoder(Picture) {
  use <- decode.recursive
  use ty <- decode.field("type", decode.string)

  case ty {
    "arc" -> {
      use radius <- decode.field("radius", decode.float)
      use start <- decode.field("start", decode_angle())
      use end <- decode.field("end", decode_angle())
      decode.success(types.Arc(radius, start:, end:))
    }
    "blank" -> decode.success(types.Blank)
    "combine" -> {
      use pictures <- decode.field(
        "pictures",
        decode.list(of: decode_picture()),
      )
      decode.success(types.Combine(pictures))
    }
    "fill" -> {
      use picture <- decode.field("picture", decode_picture())
      use colour <- decode.field("colour", colour.decoder())
      decode.success(types.Fill(picture, colour))
    }
    "polygon" -> {
      use points <- decode.field("points", decode.list(of: decode_vec2()))
      use closed <- decode.field("closed", decode.bool)
      decode.success(types.Polygon(points, closed))
    }
    "rotate" -> {
      use angle <- decode.field("angle", decode_angle())
      use picture <- decode.field("picture", decode_picture())
      decode.success(types.Rotate(picture, angle))
    }
    "scale" -> {
      use x <- decode.field("x", decode.float)
      use y <- decode.field("y", decode.float)
      use picture <- decode.field("picture", decode_picture())
      decode.success(types.Scale(picture, #(x, y)))
    }
    "stroke" -> {
      use stroke <- decode.field("stroke", decode_stroke())
      use picture <- decode.field("picture", decode_picture())
      decode.success(types.Stroke(picture, stroke))
    }
    "text" -> {
      use text <- decode.field("text", decode.string)
      use size_px <- decode.field("sizePx", decode.int)
      decode.success(types.Text(text:, size_px:))
    }
    "font_family" -> {
      use family <- decode.field("family", decode.string)
      use picture <- decode.field("picture", decode_picture())
      decode.success(types.FontFamily(picture, family))
    }
    "text_align" -> {
      use alignment <- decode.field("alignment", decode_text_align())
      use picture <- decode.field("picture", decode_picture())
      decode.success(types.TextAlign(picture, alignment))
    }
    "text_baseline" -> {
      use baseline <- decode.field("baseline", decode_text_baseline())
      use picture <- decode.field("picture", decode_picture())
      decode.success(types.TextBaseline(picture, baseline))
    }
    "text_direction" -> {
      use direction <- decode.field("direction", decode_text_direction())
      use picture <- decode.field("picture", decode_picture())
      decode.success(types.TextDirection(picture, direction))
    }
    "translate" -> {
      use x <- decode.field("x", decode.float)
      use y <- decode.field("y", decode.float)
      use picture <- decode.field("picture", decode_picture())
      decode.success(types.Translate(picture, #(x, y)))
    }
    "image" -> {
      use id <- decode.field("id", decode.string)
      use width_px <- decode.field("width_px", decode.int)
      use height_px <- decode.field("height_px", decode.int)
      decode.success(types.ImageRef(types.Image(id:), width_px:, height_px:))
    }
    "image_scaling_behaviour" -> {
      use behaviour <- decode.field("behaviour", decode.string)
      use picture <- decode.field("picture", decode_picture())
      case behaviour {
        "smooth" ->
          decode.success(types.ImageScalingBehaviour(
            picture,
            types.ScalingSmooth,
          ))
        "pixelated" ->
          decode.success(types.ImageScalingBehaviour(
            picture,
            types.ScalingPixelated,
          ))
        _ -> decode.failure(types.Blank, "Picture")
      }
    }
    _ -> decode.failure(types.Blank, "Picture")
  }
}

fn decode_text_align() -> Decoder(TextAlign) {
  use value <- decode.then(decode.string)
  case value {
    "start" -> decode.success(TextAlignStart)
    "end" -> decode.success(TextAlignEnd)
    "left" -> decode.success(TextAlignLeft)
    "right" -> decode.success(TextAlignRight)
    "center" -> decode.success(TextAlignCenter)
    _ -> decode.failure(TextAlignStart, "TextAlign")
  }
}

fn decode_text_baseline() -> Decoder(TextBaseline) {
  use value <- decode.then(decode.string)
  case value {
    "top" -> decode.success(TextBaselineTop)
    "hanging" -> decode.success(TextBaselineHanging)
    "middle" -> decode.success(TextBaselineMiddle)
    "alphabetic" -> decode.success(TextBaselineAlphabetic)
    "ideographic" -> decode.success(TextBaselineIdeographic)
    "bottom" -> decode.success(TextBaselineBottom)
    _ -> decode.failure(TextBaselineAlphabetic, "TextBaseline")
  }
}

fn decode_text_direction() -> Decoder(TextDirection) {
  use value <- decode.then(decode.string)
  case value {
    "ltr" -> decode.success(TextDirectionLtr)
    "rtl" -> decode.success(TextDirectionRtl)
    "inherit" -> decode.success(TextDirectionInherit)
    _ -> decode.failure(TextDirectionInherit, "TextDirection")
  }
}

fn decode_stroke() -> Decoder(StrokeProperties) {
  use stroke_type <- decode.field("type", decode.string)
  case stroke_type {
    "noStroke" -> decode.success(NoStroke)
    "solidStroke" -> {
      use colour <- decode.field("colour", colour.decoder())
      use thickness <- decode.field("thickness", decode.float)
      decode.success(SolidStroke(colour, thickness))
    }
    _ -> decode.failure(NoStroke, "StrokeProperties")
  }
}

fn decode_vec2() -> Decoder(#(Float, Float)) {
  use x <- decode.field("x", decode.float)
  use y <- decode.field("y", decode.float)
  decode.success(#(x, y))
}

fn picture_to_json(picture: Picture) -> Json {
  case picture {
    types.Arc(radius:, start:, end:) ->
      json.object([
        #("type", json.string("arc")),
        #("radius", json.float(radius)),
        #("start", angle_to_json(start)),
        #("end", angle_to_json(end)),
      ])
    types.Blank -> json.object([#("type", json.string("blank"))])
    types.Combine(from) ->
      json.object([
        #("type", json.string("combine")),
        #("pictures", json.array(from:, of: picture_to_json)),
      ])
    types.Fill(picture, colour) ->
      json.object([
        #("type", json.string("fill")),
        #("colour", colour.encode(colour)),
        #("picture", picture_to_json(picture)),
      ])
    types.Polygon(points, closed:) ->
      json.object([
        #("type", json.string("polygon")),
        #(
          "points",
          json.array(from: points, of: fn(point) {
            let #(x, y) = point
            json.object([#("x", json.float(x)), #("y", json.float(y))])
          }),
        ),
        #("closed", json.bool(closed)),
      ])
    types.Rotate(picture, angle) ->
      json.object([
        #("type", json.string("rotate")),
        #("angle", angle_to_json(angle)),
        #("picture", picture_to_json(picture)),
      ])
    types.Scale(picture, #(x, y)) ->
      json.object([
        #("type", json.string("scale")),
        #("x", json.float(x)),
        #("y", json.float(y)),
        #("picture", picture_to_json(picture)),
      ])
    types.Stroke(picture, stroke) ->
      json.object([
        #("type", json.string("stroke")),
        #("stroke", stroke_to_json(stroke)),
        #("picture", picture_to_json(picture)),
      ])
    types.Text(text:, size_px:) ->
      json.object([
        #("type", json.string("text")),
        #("text", json.string(text)),
        #("sizePx", json.int(size_px)),
      ])
    types.FontFamily(picture, family) ->
      json.object([
        #("type", json.string("font_family")),
        #("family", json.string(family)),
        #("picture", picture_to_json(picture)),
      ])
    types.TextAlign(picture, alignment) ->
      json.object([
        #("type", json.string("text_align")),
        #("alignment", json.string(text_align_to_string(alignment))),
        #("picture", picture_to_json(picture)),
      ])
    types.TextBaseline(picture, baseline) ->
      json.object([
        #("type", json.string("text_baseline")),
        #("baseline", json.string(text_baseline_to_string(baseline))),
        #("picture", picture_to_json(picture)),
      ])
    types.TextDirection(picture, direction) ->
      json.object([
        #("type", json.string("text_direction")),
        #("direction", json.string(text_direction_to_string(direction))),
        #("picture", picture_to_json(picture)),
      ])
    types.Translate(picture, #(x, y)) ->
      json.object([
        #("type", json.string("translate")),
        #("x", json.float(x)),
        #("y", json.float(y)),
        #("picture", picture_to_json(picture)),
      ])
    types.ImageRef(types.Image(id:), width_px:, height_px:) -> {
      json.object([
        #("type", json.string("image")),
        #("id", json.string(id)),
        #("width_px", json.int(width_px)),
        #("height_px", json.int(height_px)),
      ])
    }
    types.ImageScalingBehaviour(picture, behaviour) ->
      json.object([
        #("type", json.string("image_scaling_behaviour")),
        #(
          "behaviour",
          json.string(case behaviour {
            types.ScalingPixelated -> "pixelated"
            types.ScalingSmooth -> "smooth"
          }),
        ),
        #("picture", picture_to_json(picture)),
      ])
  }
}

pub fn text_align_to_string(value: TextAlign) -> String {
  case value {
    TextAlignStart -> "start"
    TextAlignEnd -> "end"
    TextAlignLeft -> "left"
    TextAlignRight -> "right"
    TextAlignCenter -> "center"
  }
}

pub fn text_baseline_to_string(value: TextBaseline) -> String {
  case value {
    TextBaselineTop -> "top"
    TextBaselineHanging -> "hanging"
    TextBaselineMiddle -> "middle"
    TextBaselineAlphabetic -> "alphabetic"
    TextBaselineIdeographic -> "ideographic"
    TextBaselineBottom -> "bottom"
  }
}

pub fn text_direction_to_string(value: TextDirection) -> String {
  case value {
    TextDirectionLtr -> "ltr"
    TextDirectionRtl -> "rtl"
    TextDirectionInherit -> "inherit"
  }
}

fn stroke_to_json(stroke: StrokeProperties) -> Json {
  case stroke {
    NoStroke -> json.object([#("type", json.string("noStroke"))])
    SolidStroke(colour, thickness) ->
      json.object([
        #("type", json.string("solidStroke")),
        #("colour", colour.encode(colour)),
        #("thickness", json.float(thickness)),
      ])
  }
}

fn angle_to_json(angle: Angle) -> Json {
  let Radians(rad) = angle
  json.object([#("radians", json.float(rad))])
}
