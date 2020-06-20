module Rectangle exposing
    ( Rectangle
    , hasMinimumSize
    , height
    , normalize
    , width
    , x1_
    , x2_
    , y1_
    , y2_
    )

import Point exposing (Point)


type alias Rectangle =
    ( Point, Point )


normalize : Rectangle -> Rectangle
normalize ( ( x1, y1 ), ( x2, y2 ) ) =
    ( ( min x1 x2
      , min y1 y2
      )
    , ( max x1 x2
      , max y1 y2
      )
    )


width : Rectangle -> Float
width ( ( x1, _ ), ( x2, _ ) ) =
    abs (x1 - x2)


height : Rectangle -> Float
height ( ( _, y1 ), ( _, y2 ) ) =
    abs (y1 - y2)


x1_ : Rectangle -> Float
x1_ ( ( x1, _ ), ( x2, _ ) ) =
    min x1 x2


x2_ : Rectangle -> Float
x2_ ( ( x1, _ ), ( x2, _ ) ) =
    max x1 x2


y1_ : Rectangle -> Float
y1_ ( ( _, y1 ), ( _, y2 ) ) =
    min y1 y2


y2_ : Rectangle -> Float
y2_ ( ( _, y1 ), ( _, y2 ) ) =
    max y1 y2


hasMinimumSize : Float -> Rectangle -> Bool
hasMinimumSize minimumSideLength rectangle =
    width rectangle
        >= minimumSideLength
        && height rectangle
        >= minimumSideLength
