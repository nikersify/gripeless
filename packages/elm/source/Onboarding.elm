module Onboarding exposing (view)

import Api.Enum.OnboardingStep as OnboardingStep exposing (OnboardingStep(..))
import Components
import Gegangen exposing (formatError)
import Gegangen.Requests as Requests
import Html exposing (..)
import Html.Attributes exposing (class, href, style, target)
import Html.Events exposing (onClick)
import Icons
import Mailto
import RemoteData
import Util exposing (alternate)


createAProjectTask : Bool -> Html msg
createAProjectTask =
    viewProgressItem "Create a project" [ text "" ]


firstGripeTask : String -> msg -> Bool -> Html msg
firstGripeTask projectName clickedOpenGripeless =
    viewProgressItem
        "Your first gripe"
        [ p [ class "mb-2" ] [ text "Let's get a feel for what Gripeless is like to use." ]
        , p [ class "mb-2" ]
            [ text "Below is an example of how a gripe report activation might look like on your site:" ]
        , div [ class "my-4" ]
            [ Components.exampleBox Nothing
                (div [ class "shadow-lg p-4 bg-gray-900 rounded-b-lg rounded-tr-lg" ]
                    [ button
                        [ onClick clickedOpenGripeless
                        , class "bg-gray-700 hover:bg-gray-800 px-4 py-2 rounded text-gray-300 block mx-auto flex items-center"
                        ]
                        [ Icons.exclamation "mr-2 w-5 h-5"
                        , text ("Report an issue about " ++ projectName)
                        ]
                    ]
                )
            ]
        , p [ class "mb-2" ] [ text "Click on the button above and submit any text to proceed to the next step." ]
        , p [ class "mb-2" ] [ text "Don't worry about what you type in, you can always discard it to trash." ]
        ]


titleYourGripeTask : Bool -> Html msg
titleYourGripeTask =
    viewProgressItem
        "Title your gripe"
        [ p [ class "mb-2" ]
            [ text "Click on ", Icons.refresh "w-4 h-4 mx-1", text " at the top of the gripe list to see your gripe." ]
        , p [ class "mb-2" ]
            [ text "If you now see the gripe you've submitted, nice! Click on it to select it." ]
        , p [ class "mb-2" ]
            [ text "To be ever able to mark it as completed it needs to be given a \"title\" - aka. a quick summary of what the reporter believes is sub-par."
            ]
        , p [ class "mb-2" ]
            [ text "Click on "
            , span [ class "text-gray-500" ]
                [ Icons.edit "w-4 h-4 mr-1"
                , text "Edit title"
                ]
            , text " at the top of the gripe and add any title to proceed to the next step"
            ]
        ]


takeActionOnYourGripeTask : Bool -> Html msg
takeActionOnYourGripeTask =
    viewProgressItem
        "Take action on your gripe"
        [ p [ class "mb-2" ] [ text "Your gripe has just changed its status!" ]
        , p [ class "mb-2" ]
            [ text "It went from "
            , span [] [ text "New" ]
            , text " - which meant that the gripe had just been reported and hadn't been given a title yet - to \"Actionable\" - which as the name suggests describes gripes that are ready to be fixed."
            ]
        , p [ class "mb-2" ]
            [ text "Notice that below the gripe are two buttons - \"Complete\" and \"Discard\"."
            ]
        , p [ class "mb-2" ] [ text "Click either of them to proceed to the installation step." ]
        ]


installGripelessTask : String -> String -> Bool -> Html msg
installGripelessTask sdkURL projectName =
    viewProgressItem
        "Install Gripeless"
        [ p [ class "mb-2" ] [ text "Gripeless provides a Javascript SDK to implement those pretty modals on your sites easily." ]
        , p [ class "mb-2" ]
            [ text "Refer to the "
            , a
                [ href "/docs/"
                , target "_blank"
                , class "text-red-400"
                ]
                [ text "documentation"
                ]
            , text " for all information how to install. For future reference - this link is also always accessible from the top-right corner of your dashboard."
            ]
        , p [ class "mb-2" ] [ text "tldr: Include the following script tag on your site:" ]
        , code [ class "rounded text-sm font-mono whitespace-pre-wrap mb-2 block bg-gray-900 p-4" ]
            [ text
                ("<script src=\""
                    ++ sdkURL
                    ++ "\" async></script>"
                )
            ]
        , code [ class "rounded text-sm font-mono whitespace-pre-wrap mb-2 block bg-gray-900 p-4" ]
            [ span [ class "text-gray-500" ] [ text "// Attach the following to any button's onclick event:\n" ]
            , text ("Gripeless.modal('" ++ projectName ++ "') ")
            ]
        , p [ class "mb-2" ] [ text "Mark the gripe about gripeless not being installed (the gripe we've created) as completed to advance to the next step." ]
        ]


signInTask : Bool -> Html msg
signInTask =
    viewProgressItem
        "Sign in"
        [ p [ class "mb-2" ]
            [ text "To have persistent access to this project in the future you need to sign in!"
            ]
        , p [ class "mb-2" ] [ text "In the top-left corner click on Anonymous and then on Claim Project." ]
        ]


viewProgressItem : String -> List (Html msg) -> Bool -> Html msg
viewProgressItem title sub isCompleted =
    div [ class "mb-4" ]
        [ div [ class "flex items-center" ]
            [ div
                [ class "flex-none rounded-full h-6 w-6 flex items-center justify-center font-bold border select-none"
                , if isCompleted then
                    class "bg-green-500 border-green-600 text-green-800"

                  else
                    class "bg-gray-500 border-gray-600 text-transparent"
                ]
                [ text "✓" ]
            , div
                [ class "ml-2 text-sm"
                , if isCompleted then
                    class "line-through text-gray-600"

                  else
                    class ""
                ]
                [ text title ]
            ]
        , if isCompleted then
            text ""

          else
            div [ class "ml-8 mr-4 mb-4 mt-2 text-gray-200" ] sub
        ]


viewOnboardingInner :
    { projectName : String
    , sdkURL : String
    , clickedOpenGripeless : msg
    , clickedFinishOnboarding : msg
    , supportEmail : String
    , step : OnboardingStep
    }
    -> Html msg
viewOnboardingInner args =
    case args.step of
        ReportGripe ->
            div []
                [ installGripelessTask args.sdkURL args.projectName False ]

        -- div []
        --     [ createAProjectTask True
        --     , firstGripeTask args.projectName args.clickedOpenGripeless False
        --     ]
        TitleGripe ->
            div []
                [ titleYourGripeTask False ]

        TakeActionOnGripe ->
            div []
                [ takeActionOnYourGripeTask False ]

        SignIn ->
            div []
                [ signInTask False ]

        Install ->
            div []
                [ installGripelessTask args.sdkURL args.projectName False ]

        HaveFun ->
            div []
                [ createAProjectTask True
                , firstGripeTask args.projectName args.clickedOpenGripeless True
                , titleYourGripeTask True
                , takeActionOnYourGripeTask True
                , signInTask True
                , installGripelessTask args.sdkURL args.projectName True
                , p [ class "mb-2" ] [ text "Good job! You're now fully onboarded and ready to use Gripeless!" ]
                , p [ class "mb-2" ]
                    [ text "We're open to conversations about any feedback you might have over at "
                    , a
                        [ href
                            (Mailto.mailto args.supportEmail |> Mailto.toString)
                        , class "text-red-400"
                        ]
                        [ text args.supportEmail ]
                    , text "."
                    ]
                , p [ class "mb-2" ] [ text "Have fun!" ]
                , p [ class "mb-2" ] [ text "Click the button below this text to make this popup go away." ]
                , div [ class "text-right mt-4" ]
                    [ button
                        [ onClick args.clickedFinishOnboarding
                        , class "px-8 py-2 bg-gray-700 rounded hover:bg-gray-900"
                        ]
                        [ text "Done" ]
                    ]
                ]

        Done ->
            text ""


viewProgressBar : Float -> Html msg
viewProgressBar value =
    div [ class "h-1 flex" ]
        [ div
            [ class "flex-none"
            , style "width" (String.fromFloat (value * 100) ++ "%")
            , class "bg-green-500 rounded-l-full"
            ]
            []
        , div [ class "flex-grow bg-gray-400 rounded-r-full" ] []
        ]


stepAmount : Int
stepAmount =
    6


stepOrder : OnboardingStep -> Maybe Int
stepOrder step =
    case step of
        OnboardingStep.ReportGripe ->
            Just 1

        OnboardingStep.TitleGripe ->
            Just 2

        OnboardingStep.TakeActionOnGripe ->
            Just 3

        OnboardingStep.SignIn ->
            Just 4

        OnboardingStep.Install ->
            Just 5

        OnboardingStep.HaveFun ->
            Just 6

        OnboardingStep.Done ->
            Nothing


stepProgressText : OnboardingStep -> String
stepProgressText step =
    case stepOrder step of
        Nothing ->
            ""

        Just index ->
            "Step "
                ++ String.fromInt index
                ++ "/"
                ++ String.fromInt stepAmount


viewProgressBarForStep : OnboardingStep -> Html msg
viewProgressBarForStep step =
    case stepOrder step of
        Nothing ->
            text ""

        Just index ->
            viewProgressBar (toFloat index / toFloat stepAmount)


view :
    { clickedOpenGripeless : msg
    , clickedFinishOnboarding : msg
    , toggled : msg
    , retryOnboarding : msg
    , isExpanded : Bool
    , stepData : Requests.OnboardingResponse
    , projectName : String
    , sdkURL : String
    , supportEmail : String
    }
    -> Html msg
view args =
    case args.stepData of
        RemoteData.NotAsked ->
            text ""

        RemoteData.Loading ->
            text ""

        RemoteData.Failure error ->
            div
                [ class "fixed left-0 bottom-0 m-8"
                ]
                [ Components.viewErrorBox
                    "Failed to fetch onboarding data"
                    (formatError error)
                    args.retryOnboarding
                ]

        RemoteData.Success step ->
            case step of
                OnboardingStep.Done ->
                    text ""

                _ ->
                    div
                        [ class "fixed left-0 bottom-0 right-0 m-8 max-w-lg z-40 rounded-lg shadow-xl p-4"
                        , class "bg-gray-800 text-white"
                        ]
                        [ div
                            [ class "flex justify-between items-center mb-2" ]
                            [ button
                                [ onClick args.toggled
                                , class "text-lg font-semibold hover:text-gray-300"
                                ]
                                [ text "Onboarding"
                                , alternate
                                    args.isExpanded
                                    Icons.cheveronUp
                                    Icons.cheveronDown
                                    "w-6 h-6"
                                ]
                            , div [ class "inline-flex items-center" ]
                                [ button
                                    [ class "mr-4 text-gray-600 hover:text-gray-500 text-sm"
                                    , onClick args.clickedFinishOnboarding
                                    ]
                                    [ text "I'm a pro, skip onboarding..." ]
                                , div
                                    [ class "text-sm text-gray-600" ]
                                    [ text <| stepProgressText step ]
                                ]
                            ]
                        , div [ class "mb-4" ] [ viewProgressBarForStep step ]
                        , if args.isExpanded then
                            viewOnboardingInner
                                { clickedOpenGripeless = args.clickedOpenGripeless
                                , clickedFinishOnboarding = args.clickedFinishOnboarding
                                , projectName = args.projectName
                                , sdkURL = args.sdkURL
                                , step = step
                                , supportEmail = args.supportEmail
                                }

                          else
                            div [ class "text-sm text-gray-400 hover:text-gray-500" ]
                                [ text ""
                                , button
                                    [ onClick args.toggled ]
                                    [ text "Contents hidden, click here to show more..." ]
                                ]
                        ]
