module Page.Dashboard.Gripes exposing
    ( Model
    , Msg
    , handleTokenBeforeQuery
    , init
    , subscriptions
    , toSession
    , update
    , updatePageGripeId
    , updateSession
    , view
    )

import Api.Enum.GripeAction as GripeAction exposing (GripeAction)
import Api.Enum.GripeStatus as GripeStatus exposing (GripeStatus)
import Api.Enum.Platform as Platform exposing (Platform)
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Components
import DashboardPage exposing (DashboardPage)
import DateFormat
import DateFormat.Relative exposing (relativeTime)
import Device
import Gegangen exposing (formatError)
import Gegangen.Models
    exposing
        ( Device
        , Gripe
        , GripeTimelineItem(..)
        , GripesWithCounts
        , Project
        )
import Gegangen.Requests as Requests exposing (GripeResponse)
import Html exposing (Html, a, button, div, form, h1, h3, img, input, span, table, tbody, td, text, tr)
import Html.Attributes exposing (class, classList, disabled, href, id, maxlength, minlength, placeholder, src, style, target, title, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Icons
import Ports.Auth as Auth
import Ports.Dom
import Ports.Gripeless exposing (openGripeless)
import QueryType
import RemoteData
import Route.App as Route
import ScalarCodecs exposing (GripeID(..), KeyValueString)
import Session exposing (Session)
import Task
import Time exposing (Posix, Zone)
import Token exposing (Token)
import Url.Builder
import UserData exposing (User)
import Util exposing (alternate, flip, onSpecificKeyUp)



-- MODEL


type TitleState
    = TitleEditing String
    | TitleLoading String
    | TitleClean


type StatusState
    = StatusClean
    | StatusLoading


type CommentState
    = CommentReady String
    | CommentLoading String


type alias GripesWithCountsData =
    Requests.GripesWithCountsResponse


type alias Model =
    { session : Session
    , user : User
    , project : Project
    , gripeStatus : GripeStatus
    , gripeId : Maybe String
    , gripesWithCountsData : GripesWithCountsData
    , gripeData : Requests.GripeResponse
    , gripeMetaExpanded : Bool
    , titleState : TitleState
    , commentState : CommentState
    , statusState : StatusState
    }



-- INIT


init : Session -> User -> Project -> Maybe String -> ( Model, Cmd Msg )
init session user project maybeGripeId =
    let
        ( firstModel, firstCmd ) =
            loadGripe maybeGripeId
                { session = session
                , user = user
                , project = project
                , gripeStatus = GripeStatus.New
                , gripeId = maybeGripeId
                , gripesWithCountsData = RemoteData.NotAsked
                , gripeMetaExpanded = False
                , gripeData = RemoteData.NotAsked
                , titleState = TitleClean
                , commentState = CommentReady ""
                , statusState = StatusClean
                }

        ( secondModel, secondCmd ) =
            case maybeGripeId of
                Just _ ->
                    ( firstModel, Cmd.none )

                Nothing ->
                    loadGripesWithCountsData firstModel
    in
    ( secondModel, Cmd.batch [ firstCmd, secondCmd ] )



-- UPDATE


type Msg
    = NoOp
    | OpenGripeless String
    | RefreshGripesWithCounts
    | RefreshGripe
    | CompleteGripe
    | DiscardGripe
    | RestoreGripe
    | ClickedSelectGripeStatus GripeStatus
    | GotGripeResponse Requests.GripeResponse
    | GotUpdateTitleResponse Requests.GripeResponse
    | GotCreateCommentResponse Requests.GripeResponse
    | GotUpdateStatusResponse Requests.GripeResponse
    | GotGripesWithCountsResponse GripeStatus Requests.GripesWithCountsResponse
    | TitleClickedEdit (Maybe String)
    | TitleEdited String
    | TitleDiscarded
    | TitleSubmitted
    | ToggleGripeMetaExpanded
    | CommentFormEdited String
    | CommentFormSubmitted


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        updateOnboardingCmd =
            Auth.prepareQuery (QueryType.encode QueryType.Onboarding)
    in
    case msg of
        NoOp ->
            ( model, Cmd.none )

        OpenGripeless message ->
            ( model
            , openGripeless ( model.session.gripelessProjectName, Just message )
            )

        GotGripesWithCountsResponse gripeStatus response ->
            let
                newModel =
                    { model | gripesWithCountsData = response }

                nav =
                    navigateToGripeRoute model.session.key model.project.name
            in
            if gripeStatus == model.gripeStatus then
                case response of
                    RemoteData.Success { gripes } ->
                        case model.gripeData of
                            RemoteData.Success gripe ->
                                if gripe.status /= model.gripeStatus then
                                    case List.head gripes of
                                        Just { id } ->
                                            case id of
                                                GripeID id_ ->
                                                    ( newModel, nav (Just id_) )

                                        Nothing ->
                                            ( newModel, nav Nothing )

                                else
                                    ( newModel, Cmd.none )

                            RemoteData.NotAsked ->
                                case List.head gripes of
                                    Just { id } ->
                                        case id of
                                            GripeID id_ ->
                                                ( newModel, nav (Just id_) )

                                    Nothing ->
                                        ( newModel, nav Nothing )

                            _ ->
                                ( newModel, Cmd.none )

                    _ ->
                        ( newModel, Cmd.none )

            else
                ( model, Cmd.none )

        GotGripeResponse response ->
            case response of
                RemoteData.Success gripe ->
                    -- Ensure that the gripe's id that we received is the
                    -- same as on the model, else discard the response.
                    case ( gripe.id, model.gripeId ) of
                        ( GripeID receivedGripeId, Just modelGripeId ) ->
                            if receivedGripeId == modelGripeId then
                                if RemoteData.isNotAsked model.gripesWithCountsData then
                                    updatePageGripeStatus gripe.status
                                        { model | gripeData = response }

                                else
                                    ( { model | gripeData = response }, Cmd.none )

                            else
                                ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( { model | gripeData = response }, Cmd.none )

        GotUpdateTitleResponse response ->
            case response of
                RemoteData.Success gripe ->
                    -- Ensure that the gripe's id that we received is the
                    -- same as on the model, else discard the response.
                    case ( gripe.id, model.gripeId ) of
                        ( GripeID receivedGripeId, Just modelGripeId ) ->
                            if receivedGripeId == modelGripeId then
                                ( { model
                                    | gripeData = response
                                    , gripeStatus = gripe.status
                                    , titleState = TitleClean
                                  }
                                , Cmd.batch
                                    [ Auth.prepareQuery (QueryType.encode QueryType.GripesWithCounts)
                                    , updateOnboardingCmd
                                    ]
                                )

                            else
                                ( model, updateOnboardingCmd )

                        _ ->
                            ( model, updateOnboardingCmd )

                _ ->
                    ( { model
                        | titleState = TitleClean
                        , gripeData = response
                      }
                    , Cmd.none
                    )

        GotCreateCommentResponse response ->
            case response of
                RemoteData.Success gripe ->
                    -- Ensure that the gripe's id that we received is the
                    -- same as on the model, else discard the response.
                    case ( gripe.id, model.gripeId ) of
                        ( GripeID receivedGripeId, Just modelGripeId ) ->
                            if receivedGripeId == modelGripeId then
                                ( { model
                                    | gripeData = response
                                    , gripeStatus = gripe.status
                                    , commentState = CommentReady ""
                                  }
                                , Cmd.none
                                )

                            else
                                ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( { model | gripeData = response }, Cmd.none )

        GotUpdateStatusResponse response ->
            case response of
                RemoteData.Success gripe ->
                    -- Ensure that the gripe's id that we received is the
                    -- same as on the model, else discard it.
                    case ( gripe.id, model.gripeId ) of
                        ( GripeID receivedGripeId, Just modelGripeId ) ->
                            if receivedGripeId == modelGripeId then
                                let
                                    ( newModel, loadGripesWithCountsCmd ) =
                                        loadGripesWithCountsData
                                            { model
                                                | gripeData = response
                                                , gripeStatus = gripe.status
                                                , statusState = StatusClean
                                            }
                                in
                                ( newModel
                                , Cmd.batch
                                    [ loadGripesWithCountsCmd
                                    , updateOnboardingCmd
                                    ]
                                )

                            else
                                ( model, updateOnboardingCmd )

                        _ ->
                            ( model, updateOnboardingCmd )

                _ ->
                    ( { model | gripeData = response }, Cmd.none )

        RefreshGripesWithCounts ->
            loadGripesWithCountsData model

        RefreshGripe ->
            loadGripe model.gripeId model

        CompleteGripe ->
            ( model, Auth.prepareQuery (QueryType.encode QueryType.CompleteGripe) )

        DiscardGripe ->
            ( model, Auth.prepareQuery (QueryType.encode QueryType.DiscardGripe) )

        RestoreGripe ->
            ( model, Auth.prepareQuery (QueryType.encode QueryType.RestoreGripe) )

        ClickedSelectGripeStatus status ->
            updatePageGripeStatus status model

        TitleClickedEdit maybeInitial ->
            ( { model | titleState = TitleEditing (Maybe.withDefault "" maybeInitial) }
            , Ports.Dom.select gripeTitleInputElementId
            )

        TitleEdited str ->
            ( { model | titleState = TitleEditing str }, Cmd.none )

        TitleDiscarded ->
            ( { model | titleState = TitleClean }, Cmd.none )

        TitleSubmitted ->
            case model.titleState of
                TitleEditing title ->
                    if isTitleValid title then
                        ( { model | titleState = TitleLoading title }
                        , Cmd.batch
                            [ Task.attempt (\_ -> NoOp) (Dom.blur gripeTitleInputElementId)
                            , Auth.prepareQuery (QueryType.encode QueryType.UpdateGripeTitle)
                            ]
                        )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ToggleGripeMetaExpanded ->
            ( { model | gripeMetaExpanded = not model.gripeMetaExpanded }, Cmd.none )

        CommentFormEdited str ->
            case model.commentState of
                CommentLoading _ ->
                    ( model, Cmd.none )

                CommentReady _ ->
                    ( { model | commentState = CommentReady str }, Cmd.none )

        CommentFormSubmitted ->
            case model.commentState of
                CommentLoading _ ->
                    ( model, Cmd.none )

                CommentReady str ->
                    ( { model | commentState = CommentLoading str }
                    , Auth.prepareQuery (QueryType.encode QueryType.CreateComment)
                    )


handleTokenBeforeQuery : Model -> Auth.DecodedPrepareQueryData -> ( Model, Cmd Msg )
handleTokenBeforeQuery model { token, queryType } =
    let
        apiURL =
            model.session.apiURL
    in
    case queryType of
        Just q ->
            case q of
                -- There is a possible race condition for gripe editing
                -- requests when the user submits a gripe edit and before
                -- the authentication token is sent back from Javascript
                -- they click away into another gripe and submit an edition
                -- for that gripe.
                --
                -- It is unlikely to occur and will likely be gone once we
                -- rewrite the auth system to move away from firebase, but
                -- it's good to write it down here.
                QueryType.Gripe ->
                    case model.gripeId of
                        Just gripeId ->
                            ( model
                            , Requests.gripe
                                apiURL
                                (GripeID gripeId)
                                GotGripeResponse
                                token
                            )

                        Nothing ->
                            ( model, Cmd.none )

                QueryType.GripesWithCounts ->
                    ( model
                    , Requests.gripesWithCounts
                        apiURL
                        model.project.name
                        model.gripeStatus
                        (GotGripesWithCountsResponse model.gripeStatus)
                        token
                    )

                QueryType.UpdateGripeTitle ->
                    case ( model.gripeId, model.titleState ) of
                        ( Just gripeId, TitleLoading newTitle ) ->
                            ( model
                            , Requests.updateGripeTitle
                                apiURL
                                (GripeID gripeId)
                                newTitle
                                GotUpdateTitleResponse
                                token
                            )

                        _ ->
                            ( model, Cmd.none )

                QueryType.CreateComment ->
                    case ( model.gripeId, model.commentState ) of
                        ( Just gripeId, CommentLoading body ) ->
                            ( model
                            , Requests.createComment
                                apiURL
                                (GripeID gripeId)
                                body
                                GotCreateCommentResponse
                                token
                            )

                        ( _, _ ) ->
                            ( model, Cmd.none )

                QueryType.CompleteGripe ->
                    updateGripeStatus Requests.completeGripe token model

                QueryType.DiscardGripe ->
                    updateGripeStatus Requests.discardGripe token model

                QueryType.RestoreGripe ->
                    updateGripeStatus Requests.restoreGripe token model

                _ ->
                    ( model, Cmd.none )

        Nothing ->
            ( model, Cmd.none )


navigateToGripeRoute : Nav.Key -> String -> Maybe String -> Cmd Msg
navigateToGripeRoute key projectName maybeGripeId =
    Nav.replaceUrl key
        (Route.toString
            (Route.Dashboard projectName
                (Route.Gripes maybeGripeId)
            )
        )


loadGripe : Maybe String -> Model -> ( Model, Cmd Msg )
loadGripe maybeGripeId model =
    let
        newModel =
            { model
                | gripeId = maybeGripeId
                , gripeData =
                    case maybeGripeId of
                        Just _ ->
                            RemoteData.Loading

                        Nothing ->
                            RemoteData.NotAsked
            }
    in
    case maybeGripeId of
        Just _ ->
            ( { newModel | gripeData = RemoteData.Loading }
            , Auth.prepareQuery (QueryType.encode QueryType.Gripe)
            )

        Nothing ->
            ( newModel, Cmd.none )


loadGripesWithCountsData : Model -> ( Model, Cmd Msg )
loadGripesWithCountsData model =
    ( { model | gripesWithCountsData = RemoteData.Loading }
    , Auth.prepareQuery (QueryType.encode QueryType.GripesWithCounts)
    )


updatePageGripeId : Maybe String -> Model -> ( Model, Cmd Msg )
updatePageGripeId maybeGripeId model =
    if maybeGripeId == model.gripeId then
        ( model, Cmd.none )

    else
        let
            ( m, cmd ) =
                loadGripe maybeGripeId model
        in
        ( { m | titleState = TitleClean, commentState = CommentReady "" }, cmd )


updatePageGripeStatus : GripeStatus -> Model -> ( Model, Cmd Msg )
updatePageGripeStatus newStatus model =
    if model.gripeStatus == newStatus && model.gripesWithCountsData /= RemoteData.NotAsked then
        ( model, Cmd.none )

    else
        loadGripesWithCountsData
            { model
                | gripeStatus = newStatus
            }


updateGripeStatus : (String -> GripeID -> (GripeResponse -> Msg) -> Token -> Cmd Msg) -> Token -> Model -> ( Model, Cmd Msg )
updateGripeStatus request token model =
    case model.gripeId of
        Just id ->
            ( { model | statusState = StatusLoading }
            , request
                model.session.apiURL
                (GripeID id)
                GotUpdateStatusResponse
                token
            )

        _ ->
            ( model, Cmd.none )



-- VIEW


type alias LinkToGripe =
    GripeID -> Html.Attribute Msg


gripeTitleInputElementId : String
gripeTitleInputElementId =
    "gripe-title-input"


failedToFetchText : String
failedToFetchText =
    "Failed to fetch data"


withDefaultEllipsis : Maybe String -> String
withDefaultEllipsis =
    Maybe.withDefault "…"


timestampFormat : Posix -> Zone -> String
timestampFormat timestamp zone =
    let
        space =
            DateFormat.text " "

        comma =
            DateFormat.text ", "

        colon =
            DateFormat.text ":"
    in
    DateFormat.format
        [ DateFormat.dayOfWeekNameAbbreviated
        , comma
        , DateFormat.dayOfMonthFixed
        , space
        , DateFormat.monthNameAbbreviated
        , space
        , DateFormat.yearNumber
        , space
        , DateFormat.hourMilitaryFixed
        , colon
        , DateFormat.minuteFixed
        , colon
        , DateFormat.secondFixed
        ]
        zone
        timestamp


clip : String -> Int -> String
clip string limit =
    let
        firstLine =
            List.head (String.lines string) |> Maybe.withDefault ""
    in
    if String.length firstLine > limit then
        String.left limit firstLine ++ "…"

    else
        firstLine


formatGripeStatus : GripeStatus -> String
formatGripeStatus status =
    case status of
        GripeStatus.New ->
            "New"

        GripeStatus.Actionable ->
            "Actionable"

        GripeStatus.Done ->
            "Done"

        GripeStatus.Discarded ->
            "Discarded"


formatGripeAction : GripeAction -> String
formatGripeAction action =
    case action of
        GripeAction.Discard ->
            "Discard"

        GripeAction.Restore ->
            "Restore"

        GripeAction.Complete ->
            "Complete"


gripeStatusIcon : GripeStatus -> (String -> Html Msg)
gripeStatusIcon status =
    case status of
        GripeStatus.New ->
            Icons.inbox

        GripeStatus.Actionable ->
            Icons.exclamation

        GripeStatus.Done ->
            Icons.checkCircle

        GripeStatus.Discarded ->
            Icons.trash


gripeStatusIconColor : GripeStatus -> String
gripeStatusIconColor status =
    case status of
        GripeStatus.New ->
            "text-blue-500"

        GripeStatus.Actionable ->
            "text-red-700"

        GripeStatus.Done ->
            "text-green-600"

        GripeStatus.Discarded ->
            "text-gray-600"


notificationIconComplete : Html msg
notificationIconComplete =
    span [ class "relative" ]
        [ span [ class "w-4 h-4 text-green-600" ] [ text "✓" ] ]



-- COLUMN - SIDEBAR


sidebarGripeStatuses : GripeStatus -> GripesWithCountsData -> List (Html Msg)
sidebarGripeStatuses selectedGripeStatus gripesWithCountsData =
    let
        { new, unresolved } =
            case gripesWithCountsData of
                RemoteData.Success { counts } ->
                    { new = Just counts.new
                    , unresolved = Just counts.unresolved
                    }

                _ ->
                    { new = Nothing
                    , unresolved = Nothing
                    }

        btn =
            \mCount status ->
                Components.sidebarItemButton
                    { icon = gripeStatusIcon status
                    , selectedIconColorClass = gripeStatusIconColor status
                    , label = formatGripeStatus status
                    , badge =
                        (Maybe.andThen
                            (\v ->
                                if v == 0 then
                                    Nothing

                                else
                                    Just v
                            )
                            >> Maybe.map
                                (String.fromInt
                                    >> text
                                )
                        )
                            mCount
                    , isSelected = status == selectedGripeStatus
                    , onSelect = ClickedSelectGripeStatus status
                    }
    in
    [ Components.sidebarSection
        [ Components.sidebarItemLabel "Pending"
        , btn new GripeStatus.New
        , btn unresolved GripeStatus.Actionable
        ]
    , Components.sidebarSection
        [ Components.sidebarItemLabel "Archive"
        , btn Nothing GripeStatus.Done
        , btn Nothing GripeStatus.Discarded
        ]
    ]



-- COLUMN - GRIPE LIST


viewTimestamp : String -> (List (Html msg) -> Html msg)
viewTimestamp full =
    div
        [ class "text-xs text-gray-600 mt-1"
        , title full
        ]


viewGripeListItemBody : Maybe Posix -> Maybe Zone -> Gripe -> Bool -> Html Msg
viewGripeListItemBody mNow mZone gripe selected =
    let
        timestampRelative =
            \time -> withDefaultEllipsis (Maybe.map (flip relativeTime time) mNow)

        timestampFull =
            \time -> withDefaultEllipsis (Maybe.map (timestampFormat time) mZone)

        timestamp =
            case gripe.updated of
                Nothing ->
                    viewTimestamp (timestampFull gripe.created)
                        [ text ("Created " ++ timestampRelative gripe.created) ]

                Just updated ->
                    viewTimestamp (timestampFull updated)
                        [ text ("Updated " ++ timestampRelative updated) ]
    in
    div [ class "text-sm" ]
        [ div [ class "flex justify-between items-start" ]
            [ case gripe.title of
                Just title ->
                    h3
                        [ class "text-base leading-snug mb-1 font-medium text-gray-700"
                        , classList [ ( "text-gray-900", selected ) ]
                        ]
                        [ text title ]

                Nothing ->
                    case gripe.status of
                        GripeStatus.New ->
                            div
                                [ class "mb-1 text-gray-700 uppercase font-semibold tracking-tight" ]
                                [ Icons.announcement "w-4 h-4 mr-1 text-red-700"
                                , text "New gripe - add a title"
                                ]

                        _ ->
                            div [ class "mb-1 text-gray-500 font-semibold tracking-tight" ]
                                [ text "Untitled" ]
            ]
        , case gripe.title of
            Just _ ->
                text ""

            Nothing ->
                div
                    [ class "text-gray-600 whitespace-pre-wrap" ]
                    [ text (clip gripe.body 240) ]
        , div [ class "flex justify-between" ]
            [ timestamp
            , if gripe.hasNotification then
                if gripe.status == GripeStatus.New || gripe.status == GripeStatus.Actionable then
                    span [ title "User will be notified when you complete this gripe" ]
                        [ Icons.notification "w-4 h-4 text-gray-600" ]

                else
                    span [ title "User got notified about the completion of this gripe" ]
                        [ notificationIconComplete ]

              else
                text ""
            ]
        ]


viewGripeListItem : LinkToGripe -> Maybe Posix -> Maybe Zone -> Bool -> Gripe -> Html Msg
viewGripeListItem linkToGripe mNow mZone isSelected gripe =
    div [ class "border-b" ]
        [ a
            [ linkToGripe gripe.id
            , class "py-4 px-4 block border-l-4 border-transparent"
            , class
                (if isSelected then
                    "bg-red-100 border-red-400"

                 else
                    "bg-white hover:bg-gray-100"
                )
            ]
            [ viewGripeListItemBody mNow mZone gripe isSelected ]
        ]


viewEmptyGripeList : GripeStatus -> Html Msg
viewEmptyGripeList gripeStatus =
    div [ class "w-full mt-8 text-center px-8 select-none" ]
        [ gripeStatusIcon gripeStatus "w-32 h-32 text-gray-400 mb-2"
        , div [ class "text-gray-600 text-sm" ]
            (case gripeStatus of
                GripeStatus.New ->
                    [ text "New gripes submitted by your users will show up here." ]

                GripeStatus.Actionable ->
                    [ text "Pending gripes that have been given a title and are ready to be actioned on." ]

                GripeStatus.Done ->
                    [ text "Gripes that are finished and require no further actions." ]

                GripeStatus.Discarded ->
                    [ text "Big ol' trash can of spam and useless gripes." ]
            )
        ]


viewGripeListColumn : LinkToGripe -> Maybe Posix -> Maybe Zone -> GripesWithCountsData -> Maybe String -> GripeStatus -> Html Msg
viewGripeListColumn linkToGripe mNow mZone gripesWithCountsData maybeSelectedGripeId selectedGripeStatus =
    div []
        [ div
            [ class "px-4 py-2 uppercase font-semibold text-xs bg-gray-400 text-gray-600 flex items-center justify-between"
            ]
            [ span []
                [ text (formatGripeStatus selectedGripeStatus ++ " gripes") ]
            , button [ onClick RefreshGripesWithCounts ]
                [ Icons.refresh <|
                    "w-5 h-5 text-gray-600"
                        ++ alternate
                            (RemoteData.isLoading
                                gripesWithCountsData
                            )
                            " spin"
                            ""
                ]
            ]
        , case gripesWithCountsData of
            RemoteData.Loading ->
                Components.spinner "mt-16"

            RemoteData.NotAsked ->
                text ""

            RemoteData.Failure error ->
                Components.viewErrorBox
                    failedToFetchText
                    (formatError error)
                    RefreshGripesWithCounts

            RemoteData.Success { gripes } ->
                div []
                    (if List.length gripes > 0 then
                        List.map
                            (\gripe ->
                                viewGripeListItem
                                    linkToGripe
                                    mNow
                                    mZone
                                    (case maybeSelectedGripeId of
                                        Nothing ->
                                            False

                                        Just selectedId ->
                                            case gripe.id of
                                                GripeID id ->
                                                    selectedId == id
                                    )
                                    gripe
                            )
                            gripes

                     else
                        [ viewEmptyGripeList selectedGripeStatus ]
                    )
        ]



-- COLUMN - GRIPE DETAIL


viewGripeStatus : GripeStatus -> Html Msg
viewGripeStatus status =
    div
        [ class "px-2 py-1 items-center rounded inline-flex border select-none bg-white"
        , class
            (case status of
                GripeStatus.New ->
                    "bg-blue-100 text-blue-700 border-blue-200"

                GripeStatus.Actionable ->
                    "bg-red-100 text-red-800 border-red-400"

                GripeStatus.Done ->
                    "bg-green-100 text-green-800 border-green-200"

                GripeStatus.Discarded ->
                    "bg-gray-200 text-gray-600 border-gray-400"
            )
        ]
        [ gripeStatusIcon status "w-5 h-5"
        , span [ class "ml-2 text-gray-700 font-medium" ] [ text (formatGripeStatus status) ]
        ]


viewGripeCompleteNotification : GripeStatus -> Bool -> Html msg
viewGripeCompleteNotification gripeStatus hasNotification =
    let
        notificationInfo icon t =
            div [ class "text-gray-600 flex items-center text-sm mr-4 select-none mb-4" ]
                [ span [ class "mr-1" ] [ icon ]
                , text t
                ]

        notificationInfoWillBeNotified =
            notificationInfo
                (Icons.notification "w-4 h-4")
                "User will be notified when you complete this gripe"

        noNotificationInfo =
            div
                [ class "text-gray-600 flex items-center text-sm mr-4 mb-4" ]
                [ div [ class "relative w-4 h-4 mr-1" ]
                    [ Icons.notification "w-4 h-4 absolute text-gray-500"
                    , Icons.x "w-8 h-8 -left-2 -top-2 absolute text-gray-500"
                    ]
                , div
                    [ class "border-b border-dotted border-gray-700 cursor-help"
                    , title "User didn't leave their email nor it was provided through the SDK. You can learn how to prefill user emails in our documentation."
                    ]
                    [ span [ class "mr-1" ] [ text "Notification disabled" ]
                    , Icons.help "w-4 h-4"
                    ]
                ]
    in
    case ( gripeStatus, hasNotification ) of
        ( GripeStatus.Done, True ) ->
            notificationInfo notificationIconComplete "User got notified!"

        ( GripeStatus.Done, False ) ->
            text ""

        ( GripeStatus.New, True ) ->
            notificationInfoWillBeNotified

        ( GripeStatus.New, False ) ->
            noNotificationInfo

        ( GripeStatus.Actionable, True ) ->
            notificationInfoWillBeNotified

        ( GripeStatus.Actionable, False ) ->
            noNotificationInfo

        ( GripeStatus.Discarded, _ ) ->
            text ""


isTitleValid : String -> Bool
isTitleValid title =
    let
        length =
            String.length title
    in
    length >= 1 && length <= 64


viewGripeTitleForm : String -> Bool -> Html Msg
viewGripeTitleForm title loading =
    form
        [ onSubmit TitleSubmitted
        , class "m-0"
        ]
        [ div [ class "flex" ]
            [ div [ class "relative flex-grow" ]
                [ input
                    [ value title
                    , onSpecificKeyUp "Escape" TitleDiscarded
                    , onInput TitleEdited
                    , placeholder "Provide a summary of what the user thinks is wrong"
                    , minlength 1
                    , maxlength 64
                    , id gripeTitleInputElementId
                    , class "w-full shadow rounded px-4 py-2 border flex-grow pr-12"
                    , classList
                        [ ( "bg-gray-300 text-gray-600"
                          , loading
                          )
                        ]
                    , disabled loading
                    ]
                    []
                , button
                    [ class "text-gray-600 border-transparent border p-2 absolute top-0 right-0"
                    , onClick TitleDiscarded
                    , type_ "button"
                    ]
                    [ if loading then
                        Icons.halfCircle "spin w-6 h-6"

                      else
                        Icons.x "w-6 h-6"
                    ]
                ]
            , button
                [ class "px-4 py-2 ml-2 border rounded shadow bg-white"
                , class
                    (alternate
                        (not (isTitleValid title) || loading)
                        "bg-gray-300 text-gray-700 cursor-not-allowed"
                        "hover:bg-gray-200"
                    )
                , type_ "submit"
                , disabled (not (isTitleValid title))
                ]
                [ text "Update Title" ]
            ]
        ]


viewGripeTitle : TitleState -> Maybe String -> Html Msg
viewGripeTitle titleState maybeTitle =
    div
        (List.concat
            [ [ class "mb-4"
              ]
            , case maybeTitle of
                Nothing ->
                    [ class "group" ]

                _ ->
                    []
            ]
        )
        [ case titleState of
            TitleClean ->
                div
                    (case maybeTitle of
                        Just _ ->
                            []

                        Nothing ->
                            [ onClick (TitleClickedEdit maybeTitle)
                            , class "cursor-pointer"
                            ]
                    )
                    [ h1 [ class "mb-1" ]
                        [ span
                            [ class "text-3xl leading-tight"
                            , class
                                (case maybeTitle of
                                    Just _ ->
                                        "font-bold"

                                    Nothing ->
                                        "text-gray-500 font-bold"
                                )
                            ]
                            [ case maybeTitle of
                                Just title ->
                                    text title

                                Nothing ->
                                    span [ class "group-hover:text-red-700" ]
                                        [ text "Untitled..." ]
                            ]
                        ]
                    , button
                        []
                        [ div
                            (List.concat
                                [ [ class "flex items-center text-gray-500" ]
                                , case maybeTitle of
                                    Nothing ->
                                        [ class "group-hover:text-red-700"
                                        ]

                                    _ ->
                                        [ onClick (TitleClickedEdit maybeTitle)
                                        , class
                                            "hover:text-red-700"
                                        ]
                                ]
                            )
                            [ Icons.edit "w-4 h-4"
                            , span [ class "ml-1" ] [ text "Edit Title" ]
                            ]
                        ]
                    ]

            TitleEditing value_ ->
                viewGripeTitleForm value_ False

            TitleLoading value_ ->
                viewGripeTitleForm value_ True
        ]


viewGripeHeader : GripeStatus -> Bool -> StatusState -> Html Msg
viewGripeHeader status hasNotification state =
    div
        [ class "flex justify-between" ]
        [ viewGripeStatus status
        , viewGripeActions status hasNotification state
        ]


gripeActionButton : String -> Maybe msg -> Html msg -> Html msg
gripeActionButton classes maybeMsg contents =
    let
        isDisabled =
            case maybeMsg of
                Just _ ->
                    False

                Nothing ->
                    True
    in
    button
        [ class "px-3 py-1 bg-white border inline-flex items-center"
        , class classes
        , case maybeMsg of
            Just msg ->
                onClick msg

            Nothing ->
                class ""
        , if isDisabled then
            class "select-none cursor-default text-sm border-gray-400 text-gray-600 bg-gray-200"

          else
            class "hover:bg-gray-100 shadow-md"
        , disabled isDisabled
        ]
        [ contents ]


viewGripeActions : GripeStatus -> Bool -> StatusState -> Html Msg
viewGripeActions status hasNotification statusState =
    let
        btn msg =
            gripeActionButton "rounded" (Just msg)

        disabledBtn =
            gripeActionButton "rounded" Nothing

        completeButtonInner =
            div
                [ class "flex items-center font-bold" ]
                [ Icons.checkCircle "w-5 h-5 mr-2 text-green-600"
                , span [ class "mr-1" ] [ text "Complete" ]
                , if hasNotification then
                    Icons.notification "w-4 h-4 text-gray-900"

                  else
                    text ""
                ]

        disabledCompleteButtonInner =
            div
                [ class "flex items-center font-bold"
                , title "You need to add a title to this gripe to be able to complete it."
                ]
                [ Icons.checkCircle "w-5 h-5 mr-2 text-gray-600"
                , span [ class "mr-1" ] [ text "Complete" ]
                , if hasNotification then
                    Icons.notification "w-4 h-4 text-gray-800"

                  else
                    text ""
                ]

        discardButtonInner =
            span [ class "text-gray-700 text-sm" ] [ text "Discard" ]

        spacer =
            div [ class "w-2" ] []
    in
    case statusState of
        StatusLoading ->
            Components.spinner ""

        StatusClean ->
            div [ class "inline-flex" ]
                (case status of
                    GripeStatus.New ->
                        [ btn DiscardGripe discardButtonInner
                        , spacer
                        , disabledBtn disabledCompleteButtonInner
                        ]

                    GripeStatus.Actionable ->
                        [ btn DiscardGripe discardButtonInner
                        , spacer
                        , btn CompleteGripe completeButtonInner
                        ]

                    GripeStatus.Discarded ->
                        [ btn RestoreGripe (text "Restore") ]

                    GripeStatus.Done ->
                        [ disabledBtn (text "This gripe is done.") ]
                )


formatMaybeRelativeTime : Maybe Posix -> Posix -> String
formatMaybeRelativeTime maybeStart end =
    withDefaultEllipsis (Maybe.map (flip relativeTime end) maybeStart)


viewGripeTimeline : Maybe Posix -> List GripeTimelineItem -> Html Msg
viewGripeTimeline mNow timeline =
    div [ class "relative mb-4" ]
        [ div [ class "absolute inset-y-0 z-0 ml-2 w-6 flex flex-col" ]
            [ div [ class "mx-auto flex-grow bg-gray-400", style "width" "2px" ] []
            , div [ class "w-px border border-gray-500 border-dashed mx-auto flex-none h-6" ] []
            ]
        , div [ class "z-10 relative" ]
            (List.map
                (\timelineItem ->
                    case timelineItem of
                        GripeTimelineComment comment ->
                            div [ class "bg-white border mb-4 rounded-lg" ]
                                [ div [ class "p-4 whitespace-pre-wrap" ] [ text comment.body ]
                                , div [ class "text-right p-2 bg-gray-200 text-gray-700 text-sm" ]
                                    [ text <| formatMaybeRelativeTime mNow comment.created ]
                                ]

                        GripeCreatedEvent created ->
                            div [ class "flex items-center mb-4 last:pb-6" ]
                                [ div [ class "flex items-center" ]
                                    [ div [ class "text-gray-600 rounded-full bg-white border" ]
                                        [ Icons.inbox "w-6 h-6 m-2" ]
                                    ]
                                , div [ class "flex-grow ml-2 flex items-center" ]
                                    [ div [ class "text-gray-600 uppercase text-sm tracking-wide font-bold" ] [ text "Created" ]
                                    , div [ class "mx-4 h-px bg-gray-400 flex-grow" ] []
                                    , div [ class "text-sm text-gray-800" ]
                                        [ text <| formatMaybeRelativeTime mNow created ]
                                    ]
                                ]

                        GripeStatusUpdatedEvent data ->
                            div
                                [ class "flex items-center mb-4"
                                , if data.status == GripeAction.Complete || data.status == GripeAction.Discard then
                                    class ""

                                  else
                                    class "last:pb-6"
                                ]
                                [ div [ class "flex items-center" ]
                                    [ div [ class "text-gray-600 rounded-full bg-white border" ]
                                        (case data.status of
                                            GripeAction.Discard ->
                                                [ Icons.trash "w-6 h-6 m-2" ]

                                            GripeAction.Restore ->
                                                [ Icons.plusCircle "w-6 h-6 m-2" ]

                                            GripeAction.Complete ->
                                                [ Icons.checkCircle "w-6 h-6 m-2" ]
                                        )
                                    ]
                                , div [ class "flex-grow ml-2 flex items-center" ]
                                    [ div [ class "text-gray-600 uppercase text-sm tracking-wide font-bold" ]
                                        [ text (formatGripeAction data.status) ]
                                    , div [ class "mx-4 h-px bg-gray-400 flex-grow" ] []
                                    , div [ class "text-sm text-gray-800" ]
                                        [ text <| formatMaybeRelativeTime mNow data.created ]
                                    ]
                                ]

                        GripeTitleUpdatedEvent data ->
                            div [ class "mb-4 py-1 last:pb-6" ]
                                [ div [ class "flex" ]
                                    [ div [ class "flex items-center" ]
                                        [ div [ class "text-gray-600 rounded-full bg-white border" ]
                                            [ Icons.edit "w-6 h-6 m-2" ]
                                        ]
                                    , div [ class "flex-grow ml-2 flex flex-col leading-tight" ]
                                        [ div [ class "flex-grow flex items-center" ]
                                            [ div [ class "text-gray-600 uppercase text-sm tracking-wide font-bold" ] [ text "Title edited" ]
                                            , div [ class "mx-4 h-px bg-gray-400 flex-grow" ] []
                                            , div [ class "text-sm text-gray-800" ]
                                                [ text <| formatMaybeRelativeTime mNow data.created ]
                                            ]
                                        , div [ class "font-medium text-gray-800" ] [ text data.title ]
                                        ]
                                    ]
                                ]
                )
                timeline
            )
        ]


formatPlatform : Platform -> String
formatPlatform platform =
    case platform of
        Platform.Desktop ->
            "Desktop"

        Platform.Mobile ->
            "Mobile"

        Platform.Tablet ->
            "Tablet"

        Platform.Tv ->
            "TV"


viewKeyValueTable : (List (Html msg) -> Html msg) -> List ( String, Maybe String ) -> Html msg
viewKeyValueTable keyDecorator values =
    table [ class "table-auto bg-white shadow-md w-full rounded-lg" ]
        [ tbody []
            (List.map
                (\( key, maybeValue ) ->
                    tr [ class "border-b last:border-b-0 border-gray-400" ]
                        [ td [ class "w-32 py-2 px-4 font-medium text-right bg-gray-300" ]
                            [ keyDecorator [ text key ] ]
                        , td [ class "py-2 px-4 bg-white" ]
                            [ case maybeValue of
                                Nothing ->
                                    span [ class "text-sm text-gray-600" ] [ text "Unknown" ]

                                Just value ->
                                    div [ class "overflow-auto" ] [ text value ]
                            ]
                        ]
                )
                values
            )
        ]


viewGripeBody : String -> Maybe String -> Device -> List KeyValueString -> Bool -> Html Msg
viewGripeBody body maybeImageUrl device context metaExpanded =
    div [ class "mb-4" ]
        [ div
            [ class "block text-left w-full" ]
            [ div [ class "border p-4 border-l-8 bg-white rounded-t-lg" ]
                [ div [ class "whitespace-pre-wrap break-words" ]
                    [ div [] [ text body ]
                    , case maybeImageUrl of
                        Just url ->
                            div []
                                [ div []
                                    [ a
                                        [ href url
                                        , target "blank_"
                                        , class "inline-block"
                                        ]
                                        [ img
                                            [ src url
                                            , class "shadow-md rounded-lg max-w-sm mt-4"
                                            , style "max-height" "24em"
                                            ]
                                            []
                                        ]
                                    ]
                                , div []
                                    [ button
                                        [ onClick <| OpenGripeless "This screenshot looks incorrect."
                                        , class "text-xs text-red-700 hover:text-red-900"
                                        ]
                                        [ text "Report incorrect screenshot..." ]
                                    ]
                                ]

                        Nothing ->
                            div [ class "hidden" ] []
                    ]
                ]
            , div
                [ class "bg-gray-300 hover:bg-gray-400"
                , if metaExpanded then
                    class ""

                  else
                    class "rounded-b-lg"
                ]
                [ button
                    [ class "text-xs text-gray-700 px-4 border-l-8 border-transparent py-2 text-center block w-full"
                    , onClick ToggleGripeMetaExpanded
                    ]
                    (if metaExpanded then
                        [ text "Hide", Icons.cheveronUp "w-4 h-4 ml-2" ]

                     else
                        [ text "Click here to expand more info..."
                        , Icons.cheveronDown "w-4 h-4 ml-2"
                        ]
                    )
                ]
            ]
        , if metaExpanded then
            div [ class "rounded-b-lg border bg-gray-200 p-4 relative" ]
                [ div [ class "mb-4" ]
                    [ h3 [ class "font-bold text-sm mb-1" ] [ text "Device" ]
                    , viewKeyValueTable (span [])
                        [ ( "Platform", Maybe.map formatPlatform device.platform )
                        , ( "Browser", device.browser )
                        , ( "Engine", device.engine )
                        , ( "Viewport", device.viewportSize )
                        , ( "OS", device.os )
                        , ( "URL", device.url )
                        , ( "User agent", device.userAgent )
                        ]
                    ]
                , div []
                    [ h3 [ class "font-bold text-sm mb-1" ] [ text "Custom context" ]
                    , div []
                        [ case context of
                            [] ->
                                div [ class "text-sm text-gray-700" ]
                                    [ Icons.information "w-4 h-4 mr-1 pb-px"
                                    , text "Learn how to use custom context in the "
                                    , a
                                        [ href "/docs#Using%20a%20custom%20context"
                                        , class "text-red-700"
                                        ]
                                        [ text "documentation" ]
                                    , text "."
                                    ]

                            _ ->
                                viewKeyValueTable
                                    (span [ class "font-mono text-sm" ])
                                    (List.map (Tuple.mapSecond Just) context)
                        ]
                    ]
                ]

          else
            text ""
        ]


viewGripeCommentForm : Bool -> CommentState -> Html Msg
viewGripeCommentForm isMac commentState =
    let
        formValue =
            case commentState of
                CommentReady v ->
                    v

                CommentLoading v ->
                    v

        isLoading =
            case commentState of
                CommentLoading _ ->
                    True

                CommentReady _ ->
                    False

        canSubmit =
            String.length formValue > 0 && not isLoading
    in
    div [ class "p-2 border bg-white rounded-lg mb-4" ]
        [ form [ onSubmit CommentFormSubmitted ]
            [ Components.viewTextarea
                { id = Nothing
                , onInput =
                    CommentFormEdited
                , onSubmit =
                    CommentFormSubmitted
                , classes = ""
                , isDisabled = isLoading
                , isMac = isMac
                , value = formValue
                , placeholder = "Add a comment..."
                }
            , div [ class "mt-2 flex justify-end items-center" ]
                [ if canSubmit then
                    Components.viewSubmitShortcutLabel isMac

                  else
                    text ""
                , Components.viewPrimaryButton "px-4"
                    { isLoading = isLoading
                    , isDisabled = isLoading || String.length formValue == 0
                    }
                ]
            ]
        ]


viewGripeDetailColumn : Model -> Html Msg
viewGripeDetailColumn model =
    div [ class "bg-gray-100 h-full" ]
        [ -- Close current gripe on mobile
          div [ class "px-8 mt-4" ]
            [ a
                [ Route.link
                    (Route.Dashboard
                        model.project.name
                        (Route.Gripes Nothing)
                    )
                , class "lg:hidden flex items-center text-gray-700 hover:text-gray-600"
                ]
                [ Icons.cheveronLeft "w-6 h-6", text "Back to list" ]
            ]
        , case model.gripeData of
            RemoteData.Loading ->
                Components.spinner "mt-16 flex-grow"

            RemoteData.Failure error ->
                div [ class "m-8" ]
                    [ Components.viewErrorBox
                        failedToFetchText
                        (formatError error)
                        RefreshGripe
                    ]

            RemoteData.Success gripe ->
                div []
                    [ div [ class "flex-grow lg:pt-10 p-10 pt-4 max-w-3xl" ]
                        [ viewGripeHeader gripe.status gripe.hasNotification model.statusState
                        , div [ class "h-px bg-gray-300 my-4" ] []
                        , viewGripeTitle model.titleState gripe.title
                        , viewGripeBody
                            gripe.body
                            (Maybe.map
                                (\p ->
                                    Url.Builder.crossOrigin model.session.apiURL
                                        [ case String.split "" p of
                                            -- Dirty hack to drop the first slash
                                            "/" :: rest ->
                                                String.join "" rest

                                            _ ->
                                                p
                                        ]
                                        []
                                )
                                gripe.imagePath
                            )
                            gripe.device
                            gripe.context
                            model.gripeMetaExpanded
                        , viewGripeCompleteNotification gripe.status gripe.hasNotification
                        , viewGripeTimeline model.session.now gripe.timeline
                        , viewGripeCommentForm (Device.isMac model.session.device) model.commentState
                        ]
                    ]

            RemoteData.NotAsked ->
                div [ class "h-full flex items-center justify-center" ]
                    [ div
                        [ class "uppercase select-none font-semibold text-sm text-gray-500" ]
                        [ text "No gripe selected" ]
                    ]
        ]



-- DASHBOARD


view : Model -> DashboardPage Msg
view model =
    let
        gripeSelected =
            case model.gripeId of
                Just _ ->
                    True

                Nothing ->
                    False
    in
    { title =
        case model.gripeData of
            RemoteData.Success gripe ->
                Maybe.withDefault "Untitled gripe" gripe.title
                    ++ " - Dashboard"

            _ ->
                "Dashboard"
    , body =
        div [ class "h-full flex-auto flex items-stretch overflow-y-hidden" ]
            [ div
                [ class "bg-gray-200 xl:w-96 lg:w-80 w-full flex-none border-r overflow-y-auto scrolling-touch border lg:block"
                , if gripeSelected then
                    class "hidden"

                  else
                    class "block"
                ]
                [ viewGripeListColumn
                    (\(GripeID id) -> Route.link (Route.Dashboard model.project.name (Route.Gripes (Just id))))
                    model.session.now
                    model.session.zone
                    model.gripesWithCountsData
                    model.gripeId
                    model.gripeStatus
                ]
            , div
                [ class "flex-grow overflow-auto lg:block"
                , if gripeSelected then
                    class "block"

                  else
                    class "hidden"
                ]
                [ viewGripeDetailColumn model
                ]
            ]
    , sidebar =
        sidebarGripeStatuses model.gripeStatus model.gripesWithCountsData
    }



-- SUB


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- MISC


updateSession : Model -> Session -> ( Model, Cmd Msg )
updateSession model session =
    ( { model | session = session }, Cmd.none )


toSession : Model -> Session
toSession model =
    model.session
