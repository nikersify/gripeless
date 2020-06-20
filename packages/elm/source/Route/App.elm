module Route.App exposing
    ( DashboardRoute(..)
    , Route(..)
    , fromUrl
    , isPathInternal
    , link
    , toString
    )

import Html
import Html.Attributes exposing (href)
import Url exposing (Url)
import Url.Builder as Builder
import Url.Parser exposing ((</>), (<?>), Parser, map, oneOf, parse, s, string)
import Url.Parser.Query as Query


type DashboardRoute
    = Gripes (Maybe String)
    | Settings


type Route
    = NotFound
    | Dashboard String DashboardRoute
    | CreateProject
    | ClaimProject (Maybe String)
    | SelectProject (Maybe String)
    | Login (Maybe String)


rootPath : String
rootPath =
    "app"


rootParser : Parser a a
rootParser =
    s rootPath


appParser : Parser (Route -> a) a
appParser =
    oneOf
        [ map Login (s "login" <?> Query.string "project")
        , map CreateProject (s "create-project")
        , map ClaimProject (s "claim-project" <?> Query.string "key")
        , map SelectProject (s "select-project" <?> Query.string "project")
        , map Dashboard
            (s "dashboard"
                </> string
                </> oneOf
                        [ map Gripes
                            (s "gripes"
                                <?> Query.string "gripe"
                            )
                        , map Settings (s "settings")
                        ]
            )

        -- , map Settings (s "settings" </> string)
        ]


isPathInternal : Url -> Bool
isPathInternal url =
    String.startsWith ("/" ++ rootPath) url.path


fromUrl : Url -> Route
fromUrl url =
    let
        parser =
            rootParser
                </> appParser
    in
    Maybe.withDefault NotFound (parse parser url)


toString : Route -> String
toString route =
    case route of
        NotFound ->
            Builder.absolute [ rootPath, "404" ] []

        Dashboard projectName dashboardRoute ->
            let
                base =
                    [ rootPath, "dashboard", projectName ]
            in
            case dashboardRoute of
                Gripes maybeGripeId ->
                    Builder.absolute (base ++ [ "gripes" ])
                        (case maybeGripeId of
                            Just id ->
                                [ Builder.string "gripe" id ]

                            Nothing ->
                                []
                        )

                Settings ->
                    Builder.absolute (base ++ [ "settings" ]) []

        CreateProject ->
            Builder.absolute [ rootPath, "create-project" ] []

        ClaimProject maybeKey ->
            Builder.absolute [ rootPath, "claim-project" ]
                (case maybeKey of
                    Just key ->
                        [ Builder.string "key" key ]

                    Nothing ->
                        []
                )

        SelectProject maybeProjectName ->
            Builder.absolute [ rootPath, "select-project" ]
                (case maybeProjectName of
                    Just project ->
                        [ Builder.string "project" project ]

                    Nothing ->
                        []
                )

        -- Settings projectName ->
        --     Builder.absolute [ rootPath, "settings", projectName ] []
        Login maybeProjectName ->
            Builder.absolute [ rootPath, "login" ]
                (case maybeProjectName of
                    Just project ->
                        [ Builder.string "project" project ]

                    Nothing ->
                        []
                )


link : Route -> Html.Attribute msg
link r =
    href (toString r)
