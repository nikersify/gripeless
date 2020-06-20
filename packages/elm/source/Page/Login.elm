module Page.Login exposing
    ( Model
    , Msg
    , init
    , subscriptions
    , toSession
    , update
    , updateSession
    , view
    )

import Api.Enum.GripeStatus as GripeStatus exposing (GripeStatus)
import AuthProvider exposing (AuthProvider)
import Browser
import Browser.Navigation as Nav
import Components
import Gegangen exposing (formatError)
import Gegangen.Models as Models
import Gegangen.Requests as Requests
import Graphql.Http
import Html exposing (..)
import Html.Attributes exposing (alt, class, href, src, type_)
import Html.Events exposing (onClick)
import Icons
import Ports.Auth as Auth
import Ports.Gripeless exposing (openGripeless)
import QueryType
import RemoteData
import Route.App as Route exposing (Route)
import Session exposing (Session)
import UserData exposing (UserDiffed)


type alias Model =
    { session : Session
    , maybeRedirectToProjectName : Maybe String
    }



-- INIT


init : Session -> Maybe String -> ( Model, Cmd Msg )
init session maybeRedirectToProjectName =
    ( { session = session
      , maybeRedirectToProjectName = maybeRedirectToProjectName
      }
    , case session.user of
        UserData.Loaded user ->
            case user of
                UserData.Anonymous _ ->
                    Cmd.none

                UserData.LoggedIn _ ->
                    Auth.prepareQuery (QueryType.encode QueryType.OwnedProjects)

        _ ->
            Cmd.none
    )



-- UPDATE


type Msg
    = OpenGripeless
    | ReloadPage
    | ClickedSignIn AuthProvider


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OpenGripeless ->
            ( model
            , openGripeless
                ( model.session.gripelessProjectName
                , Nothing
                )
            )

        ReloadPage ->
            ( model, Nav.reload )

        ClickedSignIn provider ->
            ( model, Auth.signIn (AuthProvider.toString provider) )



-- VIEW


buttonTemplate : String -> AuthProvider -> Msg -> Html Msg -> Html Msg
buttonTemplate classes provider msg icon =
    button
        [ class classes
        , class "w-full border py-2 font-semibold border rounded shadow flex items-center justify-center"
        , type_ "button"
        , onClick msg
        ]
        [ icon
        , span []
            [ text "Continue with "
            , span [ class "font-bold" ] [ text (AuthProvider.toString provider) ]
            ]
        ]


continueWithButton : AuthProvider -> Html Msg
continueWithButton provider =
    case provider of
        AuthProvider.Google ->
            buttonTemplate
                "bg-red-300 hover:bg-red-200 text-red-800 border-red-600 hover:border-red-500 hover:text-red-700"
                provider
                (ClickedSignIn provider)
                (Icons.google "mr-1 w-4 h-4")

        AuthProvider.GitHub ->
            buttonTemplate
                "bg-white hover:text-gray-600 hover:border-gray-600 text-gray-800 border-gray-800"
                provider
                (ClickedSignIn provider)
                (Icons.github "mr-1 w-4 h-4")


title : String -> Html msg
title string =
    h1 [ class "text-center text-4xl mt-4 font-black" ] [ text string ]


signInView : Html Msg
signInView =
    div []
        [ title "Sign In"
        , div [ class "mt-4 mb-8 relative sm:mx-16" ]
            [ div [ class "mb-3" ] [ continueWithButton AuthProvider.Google ]
            , div [] [ continueWithButton AuthProvider.GitHub ]
            ]
        , div [ class "text-sm text-center text-gray-600 mb-4" ]
            [ text "By signing up you agree with our "
            , a [ class "text-red-700", href "/legal" ] [ text "policies" ]
            , text "."
            ]
        ]


view : Model -> Browser.Document Msg
view model =
    { title = "Login | Gripeless"
    , body =
        [ Components.fullscreenBox model.session.host
            OpenGripeless
            [ case model.session.user of
                UserData.Loading ->
                    Components.spinner "my-16"

                UserData.Error error ->
                    Components.viewErrorBox "Authentication error" error ReloadPage

                UserData.Loaded user ->
                    case user of
                        UserData.Anonymous _ ->
                            signInView

                        _ ->
                            -- Invalid state
                            text ""
            ]
        ]
    }


oldview : Model -> Browser.Document Msg
oldview model =
    { title = "Login | Gripeless"
    , body =
        [ div
            [ class "mt-4 sm:mt-16 flex justify-center" ]
            [ div [ class "relative mx-4 w-full sm:w-128" ]
                [ div [ class "w-full sm:w-128 border p-4 text-center" ]
                    [ case model.session.user of
                        UserData.Loading ->
                            Components.spinner "mt-16"

                        UserData.Error error ->
                            div [] [ text error, signInView ]

                        UserData.Loaded user ->
                            case user of
                                UserData.Anonymous _ ->
                                    signInView

                                _ ->
                                    text ""
                    ]
                ]
            ]
        ]
    }


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


redirectToSelectProjectIfLoggedIn : UserDiffed -> Model -> ( Model, Cmd Msg )
redirectToSelectProjectIfLoggedIn userData model =
    case userData of
        UserData.Loaded (UserData.LoggedIn user) ->
            ( model, Nav.replaceUrl model.session.key (Route.toString (Route.SelectProject model.maybeRedirectToProjectName)) )

        _ ->
            ( model, Cmd.none )


updateSession : Model -> Session -> ( Model, Cmd Msg )
updateSession model session =
    let
        newModel =
            { model | session = session }
    in
    if model.session.user /= session.user then
        redirectToSelectProjectIfLoggedIn session.user newModel

    else
        ( newModel, Cmd.none )


toSession : Model -> Session
toSession model =
    model.session
