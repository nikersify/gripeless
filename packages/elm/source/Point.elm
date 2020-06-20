module Point exposing (Point, clamp)


type alias Point =
    ( Float, Float )


clamp : Point -> Point -> Point -> Point
clamp ( minX, minY ) ( maxX, maxY ) ( x, y ) =
    ( Basics.clamp minX maxX x, Basics.clamp minY maxY y )

