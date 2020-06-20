module Page.Dashboard.Settings exposing
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

import Browser.Navigation as Nav
import Components
import DashboardPage exposing (DashboardPage)
import DateFormat
import Gegangen exposing (formatError)
import Gegangen.Models as Models exposing (Plan, Project)
import Gegangen.Requests as Requests
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Icons
import Mailto
import Ports.Auth as Auth
import Ports.Stripe as Stripe
import QueryType
import RemoteData
import Route.App as Route
import Session exposing (Session)
import Time


type alias Model =
    { session : Session
    , project : Project
    , planData : Requests.PlanResponse
    , createCheckoutSessionData : Requests.CheckoutSessionResponse
    , redirectToCheckoutError : Maybe String
    }


type Msg
    = NoOp
    | ReloadPage
    | GotPlanData Requests.PlanResponse
    | GotCreateCheckoutSessionData Requests.CheckoutSessionResponse
    | GotRedirectToCheckoutError String
    | RefreshPlanData
    | ClickedSubscribe


init : Session -> Project -> ( Model, Cmd Msg )
init session project =
    loadPlanData
        { session = session
        , project = project
        , planData = RemoteData.NotAsked
        , createCheckoutSessionData = RemoteData.NotAsked
        , redirectToCheckoutError = Nothing
        }


loadPlanData : Model -> ( Model, Cmd Msg )
loadPlanData model =
    ( { model | planData = RemoteData.Loading }
    , Auth.prepareQuery (QueryType.encode QueryType.ProjectPlan)
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ReloadPage ->
            ( model, Nav.reload )

        RefreshPlanData ->
            loadPlanData model

        GotRedirectToCheckoutError error ->
            ( { model | redirectToCheckoutError = Just error }, Cmd.none )

        GotPlanData planData ->
            ( { model | planData = planData }, Cmd.none )

        GotCreateCheckoutSessionData ccsData ->
            ( { model | createCheckoutSessionData = ccsData }
            , case ccsData of
                RemoteData.Success checkoutSessionId ->
                    Stripe.redirectToCheckout checkoutSessionId

                _ ->
                    Cmd.none
            )

        ClickedSubscribe ->
            ( model
            , Auth.prepareQuery (QueryType.encode QueryType.CreateCheckoutSession)
            )


handleTokenBeforeQuery : Model -> Auth.DecodedPrepareQueryData -> ( Model, Cmd Msg )
handleTokenBeforeQuery model { token, queryType } =
    case queryType of
        Just q ->
            case q of
                QueryType.ProjectPlan ->
                    ( model
                    , Requests.projectPlan model.session.apiURL
                        model.project.name
                        GotPlanData
                        token
                    )

                QueryType.CreateCheckoutSession ->
                    let
                        redirectUrl =
                            "https://" ++ model.session.host ++ Route.toString (Route.Dashboard model.project.name Route.Settings)
                    in
                    ( { model
                        | createCheckoutSessionData = RemoteData.Loading
                      }
                    , Requests.createCheckoutSession
                        model.session.apiURL
                        { projectName = model.project.name
                        , successUrl = redirectUrl
                        , cancelUrl = redirectUrl
                        }
                        GotCreateCheckoutSessionData
                        token
                    )

                _ ->
                    ( model, Cmd.none )

        Nothing ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Stripe.redirectToCheckoutError GotRedirectToCheckoutError


viewFeatureRow : String -> Html Msg -> Html Msg
viewFeatureRow label amount =
    div [ class "py-3 border-t border-b w-full flex -mb-px items-center" ]
        [ div [ class "inline-block w-1/2 font-medium text-gray-700 text-center" ]
            [ text label ]
        , div
            [ class "inline-block w-1/2 font-bold text-center" ]
            [ amount ]
        ]


viewGrowthPlanCard : String -> Html Msg
viewGrowthPlanCard supportEmail =
    let
        featureYesIcon =
            span [ class "text-gray-600" ] [ text "✓" ]
    in
    div [ class "max-w-sm mx-auto bg-white shadow-xl rounded-lg p-4 border" ]
        [ h2 [ class "font-bold text-center text-xl mb-2" ] [ text "Growth" ]
        , p [ class "text-center text-gray-700 mb-4" ]
            [ text "More features, no branding!" ]
        , div [ class "w-5/6 mx-auto mb-4" ]
            [ viewFeatureRow "Remove Gripeless branding" featureYesIcon
            , viewFeatureRow "Technical support" featureYesIcon
            , viewFeatureRow "Support" (text "Priority")
            ]
        , div [ class "text-center flex items-center justify-center" ]
            [ span [ class "font-bold text-3xl tracking-tighter" ] [ text "$29" ]
            , span [ class "tracking-tight font-base text-2xl font-medium" ] [ text "/month" ]
            ]
        , p [ class "text-gray-700 text-sm text-center mb-4" ]
            [ a
                [ href (Mailto.mailto supportEmail |> Mailto.toString)
                , class "text-red-800"
                ]
                [ text "Contact us" ]
            , text " for longer billing periods or to get on the waiting list for collaboration features."
            ]
        , div [ class "text-center" ]
            [ button
                [ onClick ClickedSubscribe
                , class "px-6 py-2 rounded font-medium text-white text-lg bg-red-600 border-red-700 hover:bg-red-700"
                ]
                [ text "Checkout" ]
            ]
        ]


formatMonthYear : Maybe Time.Zone -> Time.Posix -> String
formatMonthYear maybeZone =
    case maybeZone of
        Nothing ->
            \_ -> "…"

        Just zone ->
            let
                space =
                    DateFormat.text " "
            in
            DateFormat.format
                [ DateFormat.dayOfMonthFixed
                , space
                , DateFormat.monthNameFull
                , space
                , DateFormat.yearNumber
                ]
                zone


viewPill : String -> Html Msg -> Html Msg
viewPill classes content =
    div
        [ class "inline-block rounded text-sm px-2 py-1 shadow"
        , class classes
        ]
        [ content ]


activePlanPill : String -> String -> List (Html Msg)
activePlanPill classes description =
    [ viewPill "font-medium bg-white rounded-r-none" (text "Active plan")
    , viewPill ("border font-bold rounded-l-none " ++ classes)
        (text description)
    ]


viewPlan : String -> String -> Plan -> Maybe Time.Zone -> Html Msg
viewPlan supportEmail projectName plan mZone =
    div [ class "border bg-gray-100 p-2 rounded" ]
        [ case plan of
            Models.FreePlan since ->
                div []
                    [ div [ class "mb-2" ] (activePlanPill "bg-gray-300 border-gray-400" "Free")
                    , div [ class "text-sm text-gray-700 mb-2" ]
                        [ text
                            ("Project created on "
                                ++ formatMonthYear mZone since
                                ++ "."
                            )
                        ]
                    , div [ class "text-sm text-gray-700 mb-2" ]
                        [ text
                            "You can use the free plan indefinitely, or subscribe to access more features, integrations, and remove branding from the SDK."
                        ]
                    , div [ class "text-lg font-bold text-center mb-2" ]
                        [ a
                            [ href "/pricing"
                            , target "_blank"
                            , class "text-red-700 hover:text-red-900"
                            ]
                            [ text "Compare plans..." ]
                        ]
                    , p [ class "text-gray-700 text-sm mb-2" ]
                        [ text "At this time we have disabled automatic checkout as we want to work with you individually on integrating Gripeless into your product and your workflow well."
                        ]
                    , p [ class "text-gray-700 text-sm" ]
                        [ a
                            [ class "text-red-700 hover:text-red-900"
                            , href (Mailto.mailto supportEmail |> Mailto.toString)
                            ]
                            [ text "Please reach out to us" ]
                        , text " if you're interested in upgrading to a higher plan."
                        ]
                    ]

            Models.GrowthPlan _ ->
                div []
                    [ div [ class "mb-2" ] (activePlanPill "bg-blue-300 border-blue-400" "Growth - $29/month")
                    , div [ class "text-sm" ]
                        [ text "You have an active subscription! You will be automatically charged every month until you cancel the subscription." ]
                    , div [ class "my-2 text-sm" ]
                        [ a
                            [ href
                                (Mailto.mailto supportEmail
                                    |> Mailto.subject
                                        "[Billing] Cancel subscription request"
                                    |> Mailto.body
                                        ("I want to cancel my subscription for my project "
                                            ++ projectName
                                            ++ ", with the cancellation taking effect as of now."
                                        )
                                    |> Mailto.toString
                                )
                            , class "text-red-800"
                            ]
                            [ text "Cancel subscription" ]
                        ]
                    ]
        ]


view : Model -> DashboardPage Msg
view model =
    { title = "Settings"
    , sidebar =
        [ Components.sidebarSection
            [ Components.sidebarItemLabel "Settings"
            , Components.sidebarItemButton
                { icon = Icons.currencyDollar
                , selectedIconColorClass = "text-gray-700"
                , label = "Billing"
                , badge = Nothing
                , isSelected = True
                , onSelect = NoOp
                }
            ]
        ]
    , body =
        div [ class "p-4 h-full max-w-xl bg-white border rounded" ]
            [ h1 [ class "font-bold text-4xl mb-4" ] [ text "Billing" ]
            , div []
                [ case model.planData of
                    RemoteData.Loading ->
                        Components.spinner "my-16"

                    RemoteData.NotAsked ->
                        text ""

                    RemoteData.Failure error ->
                        Components.viewErrorBox
                            "Failed to fetch plan data"
                            (formatError error)
                            RefreshPlanData

                    RemoteData.Success maybeSub ->
                        div []
                            [ case model.redirectToCheckoutError of
                                Nothing ->
                                    text ""

                                Just error ->
                                    div [ class "my-2" ]
                                        [ Components.viewErrorBox "Failed to redirect to checkout" error ReloadPage ]
                            , case model.createCheckoutSessionData of
                                RemoteData.Loading ->
                                    Components.spinner "my-8"

                                RemoteData.NotAsked ->
                                    text ""

                                RemoteData.Failure error ->
                                    div [ class "mb-2" ]
                                        [ Components.viewErrorBox
                                            "Failed to create a checkout session"
                                            (formatError error)
                                            ClickedSubscribe
                                        ]

                                RemoteData.Success _ ->
                                    text ""
                            , viewPlan
                                model.session.supportEmail
                                model.project.name
                                maybeSub
                                model.session.zone
                            ]
                ]
            ]
    }


updateSession : Model -> Session -> ( Model, Cmd Msg )
updateSession model session =
    ( { model | session = session }, Cmd.none )


toSession : Model -> Session
toSession model =
    model.session
