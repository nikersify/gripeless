module Entry.App exposing (main)

import Browser
import Browser.Navigation as Nav
import Device
import Gegangen exposing (formatError)
import Gegangen.Requests as Requests
import Html
import Page.ClaimProject as ClaimProject
import Page.CreateProject as CreateProject
import Page.Dashboard as Dashboard
import Page.Login as Login
import Page.NotFound as NotFound
import Page.SelectProject as SelectProject
import Ports.Auth as Auth
import QueryType
import RemoteData
import Resources exposing (Resources)
import Route.App as Route exposing (Route)
import Session exposing (Session)
import Task
import Time exposing (Posix)
import Url exposing (Url)
import UserData



-- MAIN --


type alias Flags =
    { demoProjectName : String
    , gripelessProjectName : String
    , host : String
    , device : Device.DeviceMeta
    , supportEmail : String
    , resources : Resources
    , apiURL : String
    , sdkURL : String
    }


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
        }



-- MODEL --


type Model
    = NotFound Session
    | Dashboard Dashboard.Model
    | CreateProject CreateProject.Model
    | ClaimProject ClaimProject.Model
    | SelectProject SelectProject.Model
    | Login Login.Model


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        ( model, cmd ) =
            changeRouteTo (Route.fromUrl url)
                (NotFound
                    (Session.init
                        { key = key
                        , host = flags.host
                        , device = Device.encode flags.device
                        , gripelessProjectName = flags.gripelessProjectName
                        , demoProjectName = flags.demoProjectName
                        , supportEmail = flags.supportEmail
                        , apiURL = flags.apiURL
                        , sdkURL = flags.sdkURL
                        , resources = flags.resources
                        }
                    )
                )
    in
    ( model
    , Cmd.batch
        [ cmd
        , Task.perform GotNow Time.now
        , Task.perform GotZone Time.here
        ]
    )



-- UPDATE --


type Msg
    = ClickedLink Browser.UrlRequest
    | ChangedUrl Url
    | GotNotFoundMsg NotFound.Msg
    | GotDashboardMsg Dashboard.Msg
    | GotLoginMsg Login.Msg
    | GotSelectProjectMsg SelectProject.Msg
    | GotCreateProjectMsg CreateProject.Msg
    | GotClaimProjectMsg ClaimProject.Msg
    | GotNow Posix
    | GotZone Time.Zone
    | GotUserData Requests.UserResponse
    | GotSignInError String
    | GotUserUID (Maybe Auth.UserUIDData)
    | GotTokenBeforeQuery Auth.DecodedPrepareQueryData


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        session =
            toSession model
    in
    case ( msg, model ) of
        ( ClickedLink urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    if Route.isPathInternal url then
                        ( model, Nav.pushUrl session.key (Url.toString url) )

                    else
                        ( model, Nav.load (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        ( ChangedUrl url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

        ( GotNow time, _ ) ->
            updateSession model (Session.updateNow session time)

        ( GotZone zone, _ ) ->
            updateSession model (Session.updateZone session zone)

        ( GotUserUID Nothing, _ ) ->
            updateSession model (Session.updateUser session UserData.Loading)

        ( GotUserUID (Just ( uid, isAnonymous )), _ ) ->
            if isAnonymous then
                updateSession model (Session.updateUser session (UserData.Loaded (UserData.Anonymous uid)))

            else
                ( model
                , Auth.prepareQuery (QueryType.encode QueryType.Me)
                )

        ( GotUserData userData, _ ) ->
            case userData of
                RemoteData.Failure error ->
                    updateSession model
                        (Session.updateUser
                            session
                            (UserData.Error (formatError error))
                        )

                RemoteData.Success user ->
                    -- updateSession model (Session.updateUser session user)
                    updateSession model
                        (Session.updateUser
                            session
                            (UserData.Loaded (UserData.LoggedIn user))
                        )

                _ ->
                    ( model, Cmd.none )

        ( GotSignInError error, _ ) ->
            updateSession model
                (Session.updateUser session (UserData.Error error))

        ( GotTokenBeforeQuery tokenData, _ ) ->
            case tokenData.queryType of
                Just QueryType.Me ->
                    ( model
                    , Requests.me
                        session.apiURL
                        GotUserData
                        tokenData.token
                    )

                _ ->
                    case model of
                        NotFound _ ->
                            noOp model

                        Dashboard dashboard ->
                            Dashboard.handleTokenBeforeQuery dashboard tokenData
                                |> updateWith Dashboard GotDashboardMsg

                        CreateProject createProject ->
                            CreateProject.handleTokenBeforeQuery createProject tokenData
                                |> updateWith CreateProject GotCreateProjectMsg

                        ClaimProject claimProject ->
                            ClaimProject.handleTokenBeforeQuery claimProject tokenData
                                |> updateWith ClaimProject GotClaimProjectMsg

                        SelectProject selectProject ->
                            SelectProject.handleTokenBeforeQuery selectProject tokenData
                                |> updateWith SelectProject GotSelectProjectMsg

                        Login _ ->
                            noOp model

        ( GotNotFoundMsg subMsg, NotFound notFound ) ->
            NotFound.update subMsg notFound
                |> updateWith NotFound GotNotFoundMsg

        ( GotDashboardMsg subMsg, Dashboard dashboard ) ->
            Dashboard.update subMsg dashboard
                |> updateWith Dashboard GotDashboardMsg

        ( GotCreateProjectMsg subMsg, CreateProject createProject ) ->
            CreateProject.update subMsg createProject
                |> updateWith CreateProject GotCreateProjectMsg

        ( GotClaimProjectMsg subMsg, ClaimProject claimProject ) ->
            ClaimProject.update subMsg claimProject
                |> updateWith ClaimProject GotClaimProjectMsg

        ( GotSelectProjectMsg subMsg, SelectProject selectProject ) ->
            SelectProject.update subMsg selectProject
                |> updateWith SelectProject GotSelectProjectMsg

        ( GotLoginMsg subMsg, Login login ) ->
            Login.update subMsg login
                |> updateWith Login GotLoginMsg

        -- Cases (x, _) cover for messages that arrive at wrong pages
        -- (e.g. api request after switching from the original page)
        ( GotDashboardMsg _, _ ) ->
            noOp model

        ( GotLoginMsg _, _ ) ->
            noOp model

        ( GotCreateProjectMsg _, _ ) ->
            noOp model

        ( GotClaimProjectMsg _, _ ) ->
            noOp model

        ( GotSelectProjectMsg _, _ ) ->
            noOp model

        ( GotNotFoundMsg _, _ ) ->
            noOp model


updateWith :
    (subModel -> Model)
    -> (subMsg -> Msg)
    -> ( subModel, Cmd subMsg )
    -> ( Model, Cmd Msg )
updateWith toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel, Cmd.map toMsg subCmd )


updateSession : Model -> Session -> ( Model, Cmd Msg )
updateSession model session =
    case model of
        NotFound _ ->
            ( NotFound session, Cmd.none )

        Dashboard dashboard ->
            Dashboard.updateSession dashboard session
                |> updateWith Dashboard GotDashboardMsg

        CreateProject createProject ->
            CreateProject.updateSession createProject session
                |> updateWith CreateProject GotCreateProjectMsg

        ClaimProject claimProject ->
            ClaimProject.updateSession claimProject session
                |> updateWith ClaimProject GotClaimProjectMsg

        SelectProject selectProject ->
            SelectProject.updateSession selectProject session
                |> updateWith SelectProject GotSelectProjectMsg

        Login login ->
            Login.updateSession login session
                |> updateWith Login GotLoginMsg



-- Login (Login.updateSession login session)


toSession : Model -> Session
toSession page =
    case page of
        NotFound session ->
            session

        Dashboard dashboard ->
            Dashboard.toSession dashboard

        CreateProject createProject ->
            CreateProject.toSession createProject

        ClaimProject claimProject ->
            ClaimProject.toSession claimProject

        SelectProject selectProject ->
            SelectProject.toSession selectProject

        Login login ->
            Login.toSession login


noOp : Model -> ( Model, Cmd Msg )
noOp model =
    ( model, Cmd.none )


changeRouteTo : Route -> Model -> ( Model, Cmd Msg )
changeRouteTo route model =
    let
        session =
            toSession model
    in
    case route of
        Route.NotFound ->
            ( NotFound session, Cmd.none )

        Route.Dashboard projectName dashboardRoute ->
            case model of
                -- Nest dashboard's "router"
                Dashboard dashboard ->
                    Dashboard.updateRoute projectName dashboardRoute dashboard
                        |> updateWith Dashboard GotDashboardMsg

                _ ->
                    Dashboard.init session projectName dashboardRoute
                        |> updateWith Dashboard GotDashboardMsg

        Route.CreateProject ->
            CreateProject.init session
                |> updateWith CreateProject GotCreateProjectMsg

        Route.ClaimProject maybeKey ->
            ClaimProject.init session maybeKey
                |> updateWith ClaimProject GotClaimProjectMsg

        Route.SelectProject maybeProjectName ->
            SelectProject.init session maybeProjectName
                |> updateWith SelectProject GotSelectProjectMsg

        Route.Login maybeProjectName ->
            Login.init session maybeProjectName
                |> updateWith Login GotLoginMsg


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Auth.userUIDChanged GotUserUID
        , Auth.signInError GotSignInError
        , Auth.queryPrepared (Auth.decodeTokenData >> GotTokenBeforeQuery)
        , Time.every 1000 GotNow
        , case model of
            NotFound _ ->
                Sub.none

            Dashboard dashboard ->
                Sub.map GotDashboardMsg (Dashboard.subscriptions dashboard)

            CreateProject createProject ->
                Sub.map GotCreateProjectMsg (CreateProject.subscriptions createProject)

            ClaimProject claimProject ->
                Sub.map GotClaimProjectMsg (ClaimProject.subscriptions claimProject)

            SelectProject _ ->
                Sub.none

            Login login ->
                Sub.map GotLoginMsg (Login.subscriptions login)
        ]


mapBody : (subMsg -> Msg) -> Browser.Document subMsg -> Browser.Document Msg
mapBody msg { title, body } =
    { title = title
    , body = List.map (Html.map msg) body
    }


view : Model -> Browser.Document Msg
view page =
    case page of
        NotFound _ ->
            mapBody GotNotFoundMsg NotFound.view

        Login login ->
            mapBody GotLoginMsg (Login.view login)

        CreateProject createProject ->
            mapBody GotCreateProjectMsg (CreateProject.view createProject)

        ClaimProject claimProject ->
            mapBody GotClaimProjectMsg (ClaimProject.view claimProject)

        SelectProject selectProject ->
            mapBody GotSelectProjectMsg (SelectProject.view selectProject)

        Dashboard dashboard ->
            mapBody GotDashboardMsg (Dashboard.view dashboard)
