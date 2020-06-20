port module SDK.Pico exposing
    ( ExternalMsg(..)
    , Model
    , Msg(..)
    , init
    , minimumSelectionSize
    , subscriptions
    , update
    , view
    )

import Browser.Events
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Html.Events.Extra.Mouse as Mouse
import Icons
import Point exposing (Point)
import Rectangle exposing (Rectangle)
import SDK.Selection as Selection exposing (Selection)


port getPicoViewportSize : String -> Cmd msg


port gotPicoViewportSize : (Viewport -> msg) -> Sub msg



-- Model


type alias Viewport =
    { width : Float
    , height : Float
    }


type alias Model =
    { selection : Selection
    , viewport : Maybe Viewport
    }



-- INIT


init : ( Model, Cmd Msg )
init =
    ( { selection = Selection.none
      , viewport = Nothing
      }
    , getPicoViewportSize viewportID
    )



-- UPDATE


type ExternalMsg
    = Abort
    | ConfirmedSelecting Rectangle


type Msg
    = NoOp
    | ExternalMsg ExternalMsg
    | BrowserResized
    | GotViewportSize Viewport
    | MouseDownAt Point
    | MouseMove Point
    | AbortedSelecting


minimumSelectionSize : Float
minimumSelectionSize =
    100


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        MouseDownAt ( x, y ) ->
            ( { model | selection = Selection.start ( x, y ) }
            , Cmd.none
            )

        MouseMove point ->
            ( { model | selection = Selection.update point model.selection }
            , Cmd.none
            )

        AbortedSelecting ->
            ( { model | selection = Selection.none }, Cmd.none )

        BrowserResized ->
            ( model, getPicoViewportSize viewportID )

        GotViewportSize result ->
            ( { model
                | viewport = Just result
                , selection = Selection.none
              }
            , Cmd.none
            )

        ExternalMsg _ ->
            -- These are handled above the food chain, we can
            -- just ignore since this code path will never be
            -- reached
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Browser.Events.onResize (\_ _ -> BrowserResized)
        , gotPicoViewportSize GotViewportSize
        ]



-- VIEW


viewportID : String
viewportID =
    "viewport"


px : Float -> String
px f =
    String.fromFloat f ++ "px"


pxProperty : String -> Float -> Html.Attribute msg
pxProperty styleProperty n =
    style styleProperty (px n)


top : Float -> Html.Attribute msg
top =
    pxProperty "top"


right : Float -> Html.Attribute msg
right =
    pxProperty "right"


bottom : Float -> Html.Attribute msg
bottom =
    pxProperty "bottom"


left : Float -> Html.Attribute msg
left =
    pxProperty "left"


w : Float -> Html.Attribute msg
w =
    pxProperty "width"


h : Float -> Html.Attribute msg
h =
    pxProperty "height"


viewHighlightOverlay : Viewport -> Maybe ( Point, Point ) -> Html Msg
viewHighlightOverlay viewport maybeRectangle =
    let
        cover attrs =
            div (List.concat [ [ class "absolute bg-gray-200" ], attrs ]) []

        hasMinimumSize =
            maybeRectangle
                |> Maybe.map (Rectangle.hasMinimumSize minimumSelectionSize)
                |> Maybe.withDefault False
    in
    div [ class "absolute inset-0 opacity-50 pointer-events-none" ] <|
        case maybeRectangle of
            Nothing ->
                [ cover [ top 0, right 0, bottom 0, left 0 ] ]

            Just rectangle ->
                let
                    ( ( x1, y1 ), ( x2, y2 ) ) =
                        Rectangle.normalize rectangle
                in
                [ -- Top
                  cover
                    [ top 0
                    , bottom (viewport.height - y1)
                    , left 0
                    , right 0
                    ]
                , -- Right
                  cover
                    [ top 0
                    , bottom 0
                    , left x2
                    , right 0
                    ]
                , -- Bottom
                  cover
                    [ top y2
                    , bottom 0
                    , left 0
                    , right 0
                    ]
                , -- Left
                  cover
                    [ top 0
                    , bottom 0
                    , left 0
                    , right (viewport.width - x1)
                    ]
                , -- Center
                  div
                    [ class "absolute transition transition-opacity duration-75 bg-gray-500"
                    , if hasMinimumSize then
                        -- There's a weird bug in firefox that makes it when
                        -- you set the opacity here to 0 it takes like 10ms
                        -- to render a frame. Having any opacity other than
                        -- 0 seems to fix it.
                        class "opacity-1"

                      else
                        class "opacity-50"
                    , top y1
                    , right (viewport.width - x2)
                    , bottom (viewport.height - y2)
                    , left x1
                    ]
                    []
                ]


handleSelectionMouseUp : Rectangle -> Point -> Msg
handleSelectionMouseUp ( p1, _ ) p2 =
    let
        rect =
            ( p1, p2 )
    in
    if Rectangle.hasMinimumSize minimumSelectionSize rect then
        ExternalMsg <| ConfirmedSelecting rect

    else
        AbortedSelecting


viewMouseEventsOverlay : Maybe Rectangle -> Html Msg
viewMouseEventsOverlay maybeRectangle =
    div
        ([ Mouse.onDown (\e -> MouseDownAt e.clientPos)
         , class "absolute inset-0 select-none cursor-crosshair"
         ]
            ++ (case maybeRectangle of
                    Nothing ->
                        []

                    Just rectangle ->
                        [ Mouse.onMove (\e -> MouseMove e.clientPos)
                        , Mouse.onUp (\e -> handleSelectionMouseUp rectangle e.clientPos)
                        ]
               )
        )
        []


viewSelectingToolbar : Bool -> Html Msg
viewSelectingToolbar isSelecting =
    div
        [ class "flex justify-center absolute bottom-0 left-0 right-0 pointer-events-none"
        , class "transition-opacity duration-75"
        , if isSelecting then
            class "opacity-50"

          else
            class "opacity-100"
        ]
        [ div
            [ style "margin-bottom" "15vh"
            , if isSelecting then
                class "pointer-events-none"

              else
                class "pointer-events-auto"
            ]
            [ div
                [ class "bg-white mx-auto max-w-md inline-flex items-stretch rounded-lg border shadow-xl select-none" ]
                [ button
                    [ onClick (ExternalMsg Abort)
                    , class "px-2 rounded-l-lg mr-2 hover:bg-gray-400 bg-gray-300"
                    ]
                    [ Icons.x "w-6 h-6" ]
                , div
                    [ class "text-gray-700 text-sm mr-3 py-2" ]
                    [ text "Drag over the area you want to screenshot" ]
                , Icons.camera "text-gray-600 w-5 h-5 mr-3 my-2"
                ]
            ]
        ]


viewSelecting : Viewport -> Maybe ( Point, Point ) -> Html Msg
viewSelecting viewport maybeRectangle =
    div []
        [ viewHighlightOverlay viewport maybeRectangle
        , viewMouseEventsOverlay maybeRectangle
        , viewSelectingToolbar
            (case maybeRectangle of
                Just _ ->
                    True

                Nothing ->
                    False
            )
        ]


view : Model -> Html Msg
view model =
    div [ id viewportID, class "fixed inset-0" ]
        [ case model.viewport of
            Nothing ->
                text ""

            Just viewport ->
                let
                    vs =
                        viewSelecting viewport
                in
                case model.selection of
                    Selection.None ->
                        vs Nothing

                    Selection.Selecting rectangle ->
                        vs <| Just rectangle
        ]
