module SDK.Selection exposing
    ( Selection(..)
    , end
    , hasMinimumSize
    , isSelecting
    , none
    , start
    , toMaybe
    , update
    )

import Point exposing (Point)
import Rectangle exposing (Rectangle)


type Selection
    = None
    | Selecting Rectangle


none : Selection
none =
    None


isSelecting : Selection -> Bool
isSelecting selection =
    case selection of
        None ->
            False

        Selecting _ ->
            True


toMaybe : Selection -> Maybe Rectangle
toMaybe selection =
    case selection of
        None ->
            Nothing

        Selecting rectangle ->
            Just rectangle


start : Point -> Selection
start point =
    Selecting ( point, point )


update : Point -> Selection -> Selection
update p2 selection =
    case selection of
        None ->
            selection

        Selecting ( p1, _ ) ->
            Selecting ( p1, p2 )


end : Rectangle -> Selection -> Point -> Rectangle
end ( minP, maxP ) selection p2 =
    let
        clamp =
            Point.clamp minP maxP
    in
    case selection of
        Selecting ( p1, _ ) ->
            ( clamp p1, clamp p2 )

        _ ->
            ( ( 0, 0 ), ( 0, 0 ) )


hasMinimumSize : Float -> Selection -> Bool
hasMinimumSize minimumSideLength selection =
    case selection of
        None ->
            False

        Selecting rectangle ->
            Rectangle.hasMinimumSize minimumSideLength rectangle

