module Page.CreateProject exposing
    ( Model
    , Msg
    , handleTokenBeforeQuery
    , init
    , subscriptions
    , toSession
    , update
    , updateSession
    , view
    )

import Browser
import Browser.Dom exposing (focus)
import Browser.Navigation as Nav
import Components
import Debounce exposing (Debounce)
import Gegangen exposing (formatError)
import Gegangen.Requests as Requests
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onBlur, onClick, onFocus, onInput, onSubmit)
import Icons
import Ports.Auth as Auth
import Ports.Gripeless exposing (openGripeless)
import QueryType
import RemoteData
import Route.App as Route
import Session exposing (Session)
import Task
import UserData
import Util exposing (alternate)


type alias Model =
    { session : Session
    , projectNameValue : String
    , createProjectData : Requests.ProjectResponse
    , isProjectNameAvailableData : Requests.IsProjectNameAvailableResponse
    , debounce : Debounce String
    }


type Msg
    = NoOp
    | DebounceMsg Debounce.Msg
    | UpdateProjectName String
    | FormSubmitted
    | OpenGripeless
    | GotCreateProjectData Requests.ProjectResponse
    | GotIsProjectNameAvailableData Requests.IsProjectNameAvailableResponse


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , projectNameValue = ""
      , createProjectData = RemoteData.NotAsked
      , isProjectNameAvailableData = RemoteData.NotAsked
      , debounce = Debounce.init
      }
    , Task.attempt (\_ -> NoOp) (focus projectNameInputID)
    )


debounceConfig : Debounce.Config Msg
debounceConfig =
    { strategy = Debounce.later 400
    , transform = DebounceMsg
    }


save : String -> Cmd Msg
save _ =
    Auth.prepareQuery
        (QueryType.encode QueryType.IsProjectNameAvailable)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        DebounceMsg msg_ ->
            let
                ( debounce, cmd ) =
                    Debounce.update
                        debounceConfig
                        (Debounce.takeLast save)
                        msg_
                        model.debounce
            in
            ( { model | debounce = debounce }, cmd )

        OpenGripeless ->
            ( model
            , openGripeless
                ( model.session.gripelessProjectName
                , Nothing
                )
            )

        UpdateProjectName name ->
            let
                newValue =
                    String.toLower name
                        |> String.filter (\c -> Char.isAlphaNum c || c == '-')

                isValid =
                    isProjectNameValid name

                newModel =
                    { model | projectNameValue = newValue }
            in
            if isValid then
                let
                    ( debounce, cmd ) =
                        Debounce.push debounceConfig name model.debounce
                in
                ( { newModel
                    | isProjectNameAvailableData = RemoteData.NotAsked
                    , debounce = debounce
                  }
                , cmd
                )

            else
                ( { newModel
                    | isProjectNameAvailableData = RemoteData.NotAsked
                  }
                , Cmd.none
                )

        FormSubmitted ->
            case model.isProjectNameAvailableData of
                RemoteData.Success { isAvailable } ->
                    if isAvailable then
                        ( { model | createProjectData = RemoteData.Loading }
                        , Auth.prepareQuery (QueryType.encode QueryType.CreateProject)
                        )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotCreateProjectData createProjectData ->
            case createProjectData of
                RemoteData.Success project ->
                    ( model
                    , Nav.replaceUrl model.session.key
                        (Route.toString
                            (Route.Dashboard project.name (Route.Gripes Nothing))
                        )
                    )

                _ ->
                    -- TODO display this error
                    ( { model | createProjectData = createProjectData }, Cmd.none )

        GotIsProjectNameAvailableData isProjectNameAvailableData ->
            ( case isProjectNameAvailableData of
                RemoteData.Success { name } ->
                    -- Ensure this response arrived for the current name
                    if name == model.projectNameValue then
                        { model | isProjectNameAvailableData = isProjectNameAvailableData }

                    else
                        model

                _ ->
                    -- Save in all cases of an error
                    { model | isProjectNameAvailableData = isProjectNameAvailableData }
            , Cmd.none
            )


handleTokenBeforeQuery : Model -> Auth.DecodedPrepareQueryData -> ( Model, Cmd Msg )
handleTokenBeforeQuery model { token, queryType } =
    case queryType of
        Just QueryType.CreateProject ->
            ( model
            , Requests.createProject
                model.session.apiURL
                model.projectNameValue
                GotCreateProjectData
                token
            )

        Just QueryType.IsProjectNameAvailable ->
            ( { model | isProjectNameAvailableData = RemoteData.Loading }
            , Requests.isProjectNameAvailable
                model.session.apiURL
                model.projectNameValue
                GotIsProjectNameAvailableData
                token
            )

        _ ->
            ( model, Cmd.none )


projectNameInputID : String
projectNameInputID =
    "project-name-input"


nameInputPlaceholder : String
nameInputPlaceholder =
    "my-project"


isProjectNameValid : String -> Bool
isProjectNameValid name =
    let
        length =
            String.length name
    in
    length >= 3 && length <= 32


nameForm : Model -> Html Msg
nameForm model =
    let
        formValid =
            isProjectNameValid model.projectNameValue

        nameLength =
            String.length model.projectNameValue

        nameInputWidthCharacters =
            String.fromInt
                (Basics.min 32 (Basics.max (String.length nameInputPlaceholder + 2) (nameLength + 2)))

        nameInputWidthStyle =
            "calc(" ++ nameInputWidthCharacters ++ "ch + 2.5em)"

        isLoading =
            case model.createProjectData of
                RemoteData.Loading ->
                    True

                _ ->
                    False
    in
    Html.form [ onSubmit FormSubmitted, class "text-center" ]
        [ label
            [ for projectNameInputID
            , class "text-gray-600 text-xs uppercase font-semibold mt-2 block"
            ]
            [ text "Project name" ]
        , div
            [ class "text-center mt-2 text-gray-600 text-sm" ]
            [ div [ class "relative inline-block" ]
                [ input
                    [ onInput UpdateProjectName
                    , id projectNameInputID
                    , value model.projectNameValue
                    , type_ "text"
                    , class "border disabled:border-transparent disabled:text-gray-600 px-4 py-2 pr-10 text-gray-800 rounded text-gray-900 font-mono text-center mx-1 text-base shadow"
                    , class "w-40" -- fallback for browsers that don't support calc()
                    , style "width" nameInputWidthStyle
                    , placeholder nameInputPlaceholder
                    , autocomplete False
                    , required True
                    , minlength 3
                    , maxlength 32
                    , pattern "[a-z-]+"
                    ]
                    []
                , div [ class "text-gray-600 p-1 absolute top-0 right-0 border border-transparent border-dashed" ]
                    [ case model.isProjectNameAvailableData of
                        RemoteData.Loading ->
                            Icons.halfCircle "w-6 h-6 m-1 spin"

                        RemoteData.Failure _ ->
                            text ""

                        RemoteData.NotAsked ->
                            Icons.edit "w-6 h-6 m-1 text-gray-400"

                        RemoteData.Success { isAvailable } ->
                            if isAvailable then
                                div
                                    [ class "font-bold py-1 text-lg pr-4 w-6 h-6 select-none" ]
                                    [ text "✓" ]

                            else
                                Icons.x "text-red-600 w-8 h-8 mr-2"
                    ]
                , case model.isProjectNameAvailableData of
                    RemoteData.Success { isAvailable } ->
                        if isAvailable then
                            text ""

                        else
                            div [ class "text-red-600 mt-1" ] [ text "This name is already taken" ]

                    _ ->
                        text ""
                ]
            ]
        , if formValid then
            text ""

          else
            div
                [ class "text-sm text-gray-700 bg-blue-100 p-2 mt-4 text-left text-blue-800 border-blue-200 border flex rounded-lg" ]
                [ div [ class "mr-2" ] [ Icons.help "w-4 h-4" ]
                , div [] [ text "Project name may contain alphanumerics and dashes and must be at least 3 characters long." ]
                ]
        , div
            [ class "mt-4 text-sm"
            , classList [ ( "text-gray-400", not formValid ) ]
            ]
            [ span [ class "mr-2" ] [ text "Will be used like:" ]
            , span
                [ class "font-mono bg-gray-200 py-2 px-4 inline-block rounded border" ]
                [ text ("gripeless.modal('" ++ model.projectNameValue ++ "')") ]
            ]
        , div [ class "text-center mt-4" ]
            [ button
                [ type_ "submit"
                , disabled isLoading
                , class
                    "px-8 py-2 border font-medium rounded text-lg"
                , if
                    formValid
                        && not isLoading
                        && (case model.isProjectNameAvailableData of
                                RemoteData.Success { isAvailable } ->
                                    isAvailable

                                _ ->
                                    False
                           )
                  then
                    class "bg-red-600 font-medium text-white border-red-700 hover:bg-red-700 hover:shadow"

                  else
                    class "cursor-not-allowed border-gray-400 bg-gray-300 text-gray-500"
                ]
                (if isLoading then
                    [ Icons.halfCircle "spin w-6 h-6" ]

                 else
                    [ text "Create project" ]
                )
            ]
        , label
            [ class "text-xs mt-2 mb-4 block"
            , class (alternate formValid "text-gray-600" "text-gray-400")
            ]
            [ text "You can always change your project's name later."
            ]
        , case model.createProjectData of
            RemoteData.Failure error ->
                div [ class "-mt-2 mb-4 text-red-600" ] [ text (formatError error) ]

            _ ->
                text ""
        ]


anonymousUserWarning : Html Msg
anonymousUserWarning =
    span []
        [ text "You are creating this project as an anonymous user. "
        , span [ class "font-bold" ] [ text "You will have access to all features" ]
        , text " with an ability to register an account and claim the project when you're ready to do so."
        ]


view : Model -> Browser.Document Msg
view model =
    { title = "Create a project | Gripeless"
    , body =
        [ Components.fullscreenBox model.session.host
            OpenGripeless
            [ h1 [ class "mt-2 text-3xl font-black" ] [ text "Create a project" ]
            , p [ class "mt-2" ] [ text "Welcome!" ]
            , p [ class "mt-2" ]
                [ text "A project contains all the complaints (aka. gripes) your users submit along with their current resolution status." ]
            , div [ class "mt-4 mb-4 border px-4 rounded bg-gray-100" ]
                [ nameForm model ]
            , case model.session.user of
                UserData.Loaded user ->
                    case user of
                        UserData.LoggedIn loggedInUser ->
                            div [ class "text-center my-2" ]
                                [ label [ class "block text-gray-600 text-sm mb-2" ]
                                    [ text "Logged in as" ]
                                , div [ class "inline-block text-left mx-auto" ]
                                    [ Components.userPill
                                        model.session.resources.defaultAvatarURL
                                        loggedInUser
                                    ]
                                ]

                        UserData.Anonymous _ ->
                            div
                                [ class "bg-yellow-100 text-sm text-yellow-800 border-yellow-400 border p-2 rounded-lg mt-2 flex"
                                ]
                                [ div [ class "mr-2" ]
                                    [ Icons.information "w-4 h-4" ]
                                , div
                                    []
                                    [ anonymousUserWarning ]
                                ]

                UserData.Error error ->
                    div [ class "bg-red-100 text-sm text-red-800 border-red-400 border p-2 rounded-lg mt-2 flex" ]
                        [ div [ class "mr-2" ]
                            [ Icons.exclamation "w-4 h-4" ]
                        , h2 [ class "font-bold" ] [ text "Authentication error" ]
                        , div []
                            [ text error ]
                        ]

                UserData.Loading ->
                    div [ class "text-gray-500 text-center text-sm" ]
                        [ Components.spinner "mt-2 mb-1"
                        , text "Authenticating…"
                        ]
            ]
        ]
    }


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


updateSession : Model -> Session -> ( Model, Cmd Msg )
updateSession model session =
    ( { model | session = session }, Cmd.none )


toSession : Model -> Session
toSession model =
    model.session
