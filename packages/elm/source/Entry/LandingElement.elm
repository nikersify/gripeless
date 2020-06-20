module Entry.LandingElement exposing (main)

import Browser
import Gegangen exposing (formatError)
import Gegangen.Models as Models exposing (Projects)
import Gegangen.Requests as Requests
import Graphql.Http
import Html exposing (Html, a, button, div, h1, hr, span, text)
import Html.Attributes exposing (class, href, type_)
import Html.Events exposing (onClick)
import Icons
import Ports.Auth as Auth
import QueryType
import RemoteData exposing (RemoteData)
import Route.App
import Token
import UserData


type Msg
    = NoOp
    | GotUserUID (Maybe Auth.UserUIDData)
    | GotUserData Requests.UserResponse
    | GotOwnedProjectsResponse Requests.OwnedProjectsResponse
    | GotTokenBeforeQuery Auth.DecodedPrepareQueryData
    | SignInError String
    | ClickedSignOut


type alias Model =
    { userDiffed : UserData.UserDiffed
    , ownedProjects : Requests.OwnedProjectsResponse
    , apiURL : String
    }


type alias Flags =
    { apiURL : String }


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { userDiffed = UserData.Loading
      , ownedProjects = RemoteData.NotAsked
      , apiURL = flags.apiURL
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotUserUID Nothing ->
            ( { model | userDiffed = UserData.Loading }, Cmd.none )

        GotUserUID (Just ( uid, isAnonymous )) ->
            if isAnonymous then
                ( { model
                    | userDiffed =
                        UserData.Loaded (UserData.Anonymous uid)
                  }
                , Cmd.none
                )

            else
                ( model
                , Auth.prepareQuery
                    (QueryType.encode QueryType.Me)
                )

        GotOwnedProjectsResponse response ->
            ( { model | ownedProjects = response }, Cmd.none )

        GotTokenBeforeQuery { queryType, token } ->
            case queryType of
                Just q ->
                    case q of
                        QueryType.OwnedProjects ->
                            ( model
                            , Requests.ownedProjects
                                model.apiURL
                                GotOwnedProjectsResponse
                                token
                            )

                        QueryType.Me ->
                            ( model
                            , Requests.me
                                model.apiURL
                                GotUserData
                                token
                            )

                        _ ->
                            ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        GotUserData userData ->
            case userData of
                RemoteData.Success userDiffed ->
                    ( { model
                        | userDiffed =
                            UserData.Loaded (UserData.LoggedIn userDiffed)
                      }
                    , Auth.prepareQuery (QueryType.encode QueryType.OwnedProjects)
                    )

                RemoteData.Failure error ->
                    ( { model | userDiffed = UserData.Error (formatError error) }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SignInError error ->
            ( { model | userDiffed = UserData.Error error }, Cmd.none )

        ClickedSignOut ->
            ( { model | userDiffed = UserData.Loading }, Auth.signOut () )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Auth.userUIDChanged GotUserUID
        , Auth.signInError SignInError
        , Auth.queryPrepared (Auth.decodeTokenData >> GotTokenBeforeQuery)
        ]


dropdownItem : (List (Html Msg) -> Html Msg) -> List (Html Msg) -> Html Msg
dropdownItem surround children =
    surround
        [ div
            [ class "w-64 hover:bg-red-300 font-medium first:rounded-t last:rounded-b px-3 py-2"
            ]
            children
        ]


dropdownSeparator : Html Msg
dropdownSeparator =
    div [ class "my-2 w-full" ] [ hr [] [] ]


goToProjectDropdown : Projects -> Html Msg
goToProjectDropdown projects =
    div [ class "inline-block group relative" ]
        [ div []
            [ div [ class "hidden group-hover:block absolute border rounded bg-white p-2 shadow-xl right-0 z-10" ]
                (List.map
                    (\project ->
                        dropdownItem
                            (a
                                [ Route.App.link
                                    (Route.App.Dashboard
                                        project.name
                                        (Route.App.Gripes Nothing)
                                    )
                                ]
                            )
                            [ text project.name ]
                    )
                    projects
                    ++ (if List.length projects > 0 then
                            [ dropdownSeparator ]

                        else
                            []
                       )
                    ++ [ dropdownItem
                            (a [ Route.App.link Route.App.CreateProject ])
                            [ span [ class "text-sm text-gray-700" ] [ text "Create a new project..." ] ]
                       ]
                )
            ]
        , button
            [ type_ "button"
            , class "border font-medium px-2 py-1 border-red-700 rounded shadow text-red-600 bg-white group-hover:bg-red-600 group-hover:text-white"
            ]
            [ text "Go to Project"
            , Icons.arrowRight "w-4 h-4 ml-2"
            ]
        ]


spinner : Html msg
spinner =
    Icons.halfCircle "spin w-8 h-8 text-gray-500"


loggedInCases : Models.User -> Model -> Html Msg
loggedInCases user model =
    case model.ownedProjects of
        RemoteData.NotAsked ->
            spinner

        RemoteData.Loading ->
            spinner

        RemoteData.Failure error ->
            div [ class "text-red-700" ] [ text ("error: " ++ formatError error) ]

        RemoteData.Success ownedProjects ->
            div [ class "flex items-center" ]
                [ button
                    [ onClick ClickedSignOut
                    , class "mr-8 text-gray-600 hover:text-gray-900"
                    , class "hidden md:block"
                    ]
                    [ text "Sign out" ]
                , goToProjectDropdown ownedProjects
                ]


view : Model -> Html Msg
view model =
    div []
        [ case model.userDiffed of
            UserData.Error userError ->
                div [ class "text-red-700" ] [ text ("Authentication error: " ++ userError) ]

            UserData.Loading ->
                spinner

            UserData.Loaded loadedUser ->
                case loadedUser of
                    UserData.Anonymous uid ->
                        a
                            [ Route.App.link (Route.App.Login Nothing)
                            , class "text-gray-600 hover:text-gray-900"
                            ]
                            [ text "Sign in" ]

                    -- , createProjectLink
                    UserData.LoggedIn user ->
                        loggedInCases user model
        ]
