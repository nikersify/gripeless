module Entry.Docs exposing (main)

import Browser
import Components
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick)
import Icons
import Json.Decode as Decode
import Mailto
import Ports.Gripeless exposing (openGripeless)
import Route.App as Route


type alias Model =
    { projectName : String
    , demoProjectName : String
    , sdkURL : String
    , supportEmail : String
    , logotypeURL : String
    }


type alias Flags =
    { projectName : String
    , demoProjectName : String
    , sdkURL : String
    , supportEmail : String
    , logotypeURL : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { demoProjectName = flags.demoProjectName
      , projectName = flags.projectName
      , sdkURL = flags.sdkURL
      , supportEmail = flags.supportEmail
      , logotypeURL = flags.logotypeURL
      }
    , Cmd.none
    )


main : Program Flags Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }


type Msg
    = OpenDemoGripeless
    | OpenGripeless


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OpenGripeless ->
            ( model, openGripeless ( model.projectName, Nothing ) )

        OpenDemoGripeless ->
            ( model, openGripeless ( model.demoProjectName, Nothing ) )


aa : List (Html.Attribute msg) -> String -> Html msg
aa attr s =
    a (attr ++ [ class "text-red-800" ]) [ text s ]


heading : (List (Html.Attribute msg) -> List (Html msg) -> Html msg) -> String -> String -> Html msg
heading node classes s =
    node [ class "group", class classes, id s ]
        [ a [ href ("#" ++ s) ]
            [ span [ class "group-hover:text-gray-700" ] [ text s ]
            , span [ class "invisible group-hover:visible text-gray-500" ]
                [ Icons.link "ml-2 w-4 h-4" ]
            ]
        ]


ha1 : String -> Html msg
ha1 =
    heading h1 "text-3xl font-bold mb-4"


ha2 : String -> Html msg
ha2 =
    heading h2 "text-2xl font-semibold mt-6 mb-2"


ha3 : String -> Html msg
ha3 =
    heading h3 "text-xl font-semibold mt-6 mb-2"


ha4 : String -> Html msg
ha4 =
    heading h4 "text-lg font-medium mt-4 mb-2"


para : String -> Html msg
para s =
    p [ class "mb-2" ] [ text s ]


paraRich : List (Html msg) -> Html msg
paraRich c =
    p [ class "mb-2" ] c


code : Html msg -> Html msg
code s =
    div [ class "font-mono bg-gray-300 whitespace-pre-wrap rounded p-4 mb-4 text-sm border border-gray-500" ]
        [ s ]


boldy : String -> Html msg
boldy s =
    span [ class "font-bold" ] [ text s ]


italic : String -> Html msg
italic s =
    span [ class "italic" ] [ text s ]


prosOrCons : Html Msg -> String -> String -> List String -> Html Msg
prosOrCons icon iconClasses textClasses items =
    div []
        (List.map
            (\s ->
                div
                    [ class "flex rounded px-1"
                    , class textClasses
                    ]
                    [ div
                        [ class "mb-4 flex-0 mr-2 w-6 h-6 flex items-center justify-center rounded-full font-bold"
                        , class iconClasses
                        ]
                        [ icon ]
                    , div [ class "flex-grow" ] [ text s ]
                    ]
            )
            items
        )


term : String -> Html Msg
term s =
    span [ class "font-mono py-px text-sm px-2 border bg-white rounded shadow" ] [ text s ]


pros : List String -> Html Msg
pros =
    prosOrCons (text "✓") "bg-green-200 text-green-700" "text-green-900"


cons : List String -> Html Msg
cons =
    prosOrCons (text "✗") "bg-red-200 text-red-800" "text-red-900"


tip : List (Html msg) -> Html msg
tip s =
    div [ class "bg-blue-100 text-blue-800 flex p-2 border border-blue-300 rounded text-sm mb-2" ]
        [ div [] [ Icons.help "w-4 h-4 mr-2 flex-0" ]
        , div [] s
        ]


onCtrlU : msg -> Attribute msg
onCtrlU msg =
    on "keydown"
        (Decode.map2 Tuple.pair
            (Decode.field "key" Decode.string)
            (Decode.field "ctrlKey" Decode.bool)
            |> Decode.andThen
                (\( key, hasCtrl ) ->
                    if key == "u" && hasCtrl then
                        Decode.succeed msg

                    else
                        Decode.fail ""
                )
        )


labeledExampleBox : String -> Html msg -> Html msg
labeledExampleBox label content =
    div [ class "mb-16" ]
        [ Components.exampleBox (Just label) content
        ]


view : Model -> Browser.Document Msg
view model =
    { title = "Documentation | Gripeless"
    , body =
        [ div [ class "min-w-screen min-h-screen bg-gray-100" ]
            [ div [ class "mx-auto max-w-3xl bg-white h-full shadow-xl px-6 py-4 pb-16 pt-16 mb-8 rounded-b-lg" ]
                [ img
                    [ src model.logotypeURL
                    , class "w-48 mx-auto mb-12"
                    ]
                    []

                -- , ha1 "How to integrate"
                , ha2 "Introduction"
                , paraRich [ text "In one sentence, ", boldy "Gripeless is a complete solution for collecting and managing user complaints website(s). ", text "Users can submit their complaints via the provided widget, and you can later triage and manage those complaints in the provided dashboard." ]
                , paraRich [ text "The widget is optimized for both mobile and desktop screens, slow network conditions, low performing devices and has been tested to work with numerous websites. As of the time of writing the whole SDK weights only around ", boldy "40kB compressed", text " therefore it loads extremely quickly even in relatively poor network conditions." ]
                , ha2 "Goal"
                , para "By the end of this guide you will have a fully integrated Gripeless widget and dashboard, all ready to take in and manage complaints."
                , para "Here're a few example ways of integrating Gripeless with your website:"
                , div [ class "mt-8" ]
                    [ labeledExampleBox "Simple button"
                        (div [ class "h-64 flex items-center justify-center" ]
                            [ div [ class "text-center" ]
                                [ button
                                    [ onClick OpenDemoGripeless
                                    , class "px-4 py-2 font-bold bg-white border rounded shadow-md flex items-center hover:bg-red-400 mb-1"
                                    ]
                                    [ Icons.exclamation "w-6 h-6 mr-2"
                                    , text "Report a problem"
                                    ]
                                , div [ class "text-sm text-gray-700" ]
                                    [ Icons.cheveronUp "w-4 h-4 mr-1"
                                    , text "Click on me!"
                                    ]
                                ]
                            ]
                        )
                    , labeledExampleBox "Activate from a page's navbar"
                        (div [ class "pb-16" ]
                            [ div [ class "rounded-tr-lg bg-gray-700 text-white flex items-center items-stretch shadow-lg" ]
                                [ div [ class "flex-0 text-xl font-thin py-4 px-4 select-none" ]
                                    [ text "Awesome App" ]
                                , div [ class "mr-2 flex-grow flex justify-end items-center" ]
                                    [ a [ class "select-none block px-3" ] [ text "Pricing" ]
                                    , a [ class "select-none block px-3" ] [ text "Login" ]
                                    , button
                                        [ onClick OpenDemoGripeless
                                        , class "px-3 font-bold self-stretch"
                                        , class "hover:bg-gray-800"
                                        ]
                                        [ text "Report a problem" ]
                                    ]
                                ]
                            ]
                        )
                    , labeledExampleBox "...or from its footer"
                        (div [ class "pt-32" ]
                            [ div [ class "bg-gray-700 text-white pl-8 py-8 rounded-b-lg" ]
                                [ div [ class "font-thin text-xl mb-4" ] [ text "Awesome App" ]
                                , div [ class "mb-1 text-gray-200" ] [ text "About us" ]
                                , div [ class "mb-1 text-gray-200" ] [ text "Site map" ]
                                , button
                                    [ onClick OpenDemoGripeless
                                    , class "mb-1 font-semibold hover:text-gray-300"
                                    ]
                                    [ text "Report a problem" ]
                                ]
                            ]
                        )
                    , labeledExampleBox "As a dropdown item"
                        (div [ class "h-48 flex items-center justify-center" ]
                            [ div [ class "group relative" ]
                                [ button
                                    [ class "border rounded px-4 py-2 font-bold bg-white shadow-md flex items-center mb-16"
                                    , class "hover:bg-red-200"
                                    ]
                                    [ Icons.help "w-6 h-6 mr-2"
                                    , text "Help"
                                    , Icons.cheveronDown "w-6 h-6 ml-2"
                                    ]
                                , div
                                    [ class "mt-12 absolute hidden group-hover:block top-0 left-0"
                                    , style "right" "-5em"
                                    ]
                                    [ div
                                        [ class "bg-white font-medium rounded border shadow-lg"
                                        ]
                                        [ div [ class "select-none" ]
                                            [ div [ class "text-gray-700 py-2 px-4 flex items-center" ]
                                                [ Icons.group "w-6 h-6 mr-4"
                                                , text "Help center"
                                                ]
                                            , div [ class "text-gray-700 py-2 px-4 flex items-center" ]
                                                [ Icons.mail "w-6 h-6 mr-4"
                                                , text "Support"
                                                ]
                                            , div [ class "text-gray-700 py-2 px-4 flex items-center" ]
                                                [ Icons.desktop "w-6 h-6 mr-4"
                                                , text "Shortcuts"
                                                ]
                                            , button
                                                [ onClick OpenDemoGripeless
                                                , class "block py-2 px-4 flex items-center w-full rounded-b font-semibold"
                                                , class
                                                    "hover:bg-red-300"
                                                ]
                                                [ Icons.exclamation "w-6 h-6 mr-4"
                                                , text "Report a problem"
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        )
                    , labeledExampleBox "Or even as a keyboard shortcut"
                        (div [ class "flex items-center justify-center" ]
                            [ div [ class "py-8 text-center" ]
                                [ input
                                    [ type_ "text"
                                    , onCtrlU OpenDemoGripeless
                                    , value ""
                                    , maxlength 0
                                    , class "rounded border py-1 px-2 shadow mb-2"
                                    ]
                                    []
                                , div [ class "text-sm text-gray-700" ]
                                    [ text "Click on the input above and press "
                                    , span [ class "bg-white border rounded p-1 font-mono text-xs" ] [ text "Ctrl + U" ]
                                    ]
                                ]
                            ]
                        )
                    ]
                , ha2 "Installation"
                , para
                    "Gripeless is designed to be as easy to integrate with your website as possible and its installation shouldn't take more than a few minutes."
                , ha3 "Step 1 — Get the .js"
                , para "To get started, you need to install the Gripeless SDK on your website. The SDK is the part that your users will interact with."
                , para "We provide two ways of installing Gripeless - either via an UMD build or via an npm package. Both have their advantages and disadvantages, listed below."
                , ha4 "Installing via CDN"
                , div [ class "mt-4" ]
                    [ pros
                        [ "Easy to install"
                        , "Automatic updates"
                        , "Distributed with Cloudflare's Global Network"
                        ]
                    ]
                , para "To install via CDN simply include this script tag in the head of your website:"
                , code <| text <| "<script src=\"" ++ model.sdkURL ++ "\" async></script>"
                , tip <|
                    [ text "The "
                    , term "async"
                    , text " attribute tells the browser that it shouldn't wait for the download before your page is ready. This is in most cases the desirable behavior as it makes the SDK have no network performance impact on your website. However, if you get errors like "
                    , term "Gripeless is not defined"
                    , text " in the browser console it might be worth dropping the "
                    , term "async"
                    , text " attribute."
                    ]
                , paraRich [ text "The above script will expose a global ", term "Gripeless", text " variable in the current document." ]
                , paraRich
                    [ text "You can verify that the SDK is installed by visiting your website and typing "
                    , term "Gripeless"
                    , text " in your browser's console. If it's not undefined, great! Move on to the next step."
                    ]
                , tip <| [ text "To get automatic updates and benefits of a globally distributed CDN please refrain from self-hosting the SDK." ]
                , ha3 "Step 2 — Activate the modal"
                , para "The SDK doesn't do anything on its own after being installed and there's no \"always there\" widget in the bottom-right corner, by design. Instead, you ought to create your own \"activator\" (e.g. a button) that will open the modal, that's styled to match the look and feel of your website."
                , ha4 "Find your project name"
                , paraRich
                    [ text "The SDK uses your, "
                    , term "project-name"
                    , text " to determine that the gripes your users submit should land into your project. You can find your exact project's name in the top left corner of your "
                    , aa
                        [ Route.link
                            (Route.SelectProject Nothing)
                        ]
                        "project's dashboard"
                    , text ", right below your name."
                    ]
                , ha4 "Create an activation"
                , paraRich
                    [ text "If you know your project name you're all set and ready to add the activation. The API is simple - there's only one method ("
                    , term "modal"
                    , text ") that requires a single argument with your project's name, like so:"
                    ]
                , code <| text "gripeless.modal('project-name')"
                , para "Here are some example activations in some popular technologies:"
                , ha4 "Vanilla"
                , code <| text "<button id=\"gripeless-button\">Gripeless</button>"
                , code <|
                    text
                        ("const gripeless = require('@gripeless/sdk')\n"
                            ++ "const $activate = document.getElementById('gripeless-button')\n"
                            ++ "$activate.addEventListener('click', () =>\n    gripeless.modal('project')\n)"
                        )
                , ha4 "Using React"
                , code <|
                    text
                        (""
                            ++ "const Gripeless = () => (\n"
                            ++ "    <button onclick={() => gripeless.modal('bungee')}>Report an issue</button>\n"
                            ++ ")"
                        )
                , ha4 "Using Vue"
                , code <|
                    text
                        ("<template>\n"
                            ++ "  <button @click=openGripeless>\n"
                            ++ "    Report an issue\n"
                            ++ "  </button>\n"
                            ++ "</template>\n"
                            ++ "\n"
                            ++ "<script>\n"
                            ++ "import gripeless from '@gripeless/sdk';\n"
                            ++ "\n"
                            ++ "export default {\n"
                            ++ "  methods: {\n"
                            ++ "    openGripeless: () => gripeless.modal('project')\n"
                            ++ "  }\n"
                            ++ "};\n"
                            ++ "</script>"
                        )
                , ha3 "Step 3 — Try it out"
                , paraRich
                    [ text "After installing and setting up everything let's make sure it all works correctly! If you get stuck at any of the steps below please feel free to "
                    , aa [ href (Mailto.mailto model.supportEmail |> Mailto.toString) ] "mail us"
                    , text " and we'll try to resolve any issues."
                    ]
                , ha4 "Send yourself a gripe"
                , para "Click your Gripeless activation button implemented in the previous step - you should see a big fullscreen modal pop up."
                , para "Type some text into the text field and click \"Submit\" - you should see a big checkmark show up which indicates that the gripe has been submitted successfully."
                , paraRich
                    [ text "Now go to "
                    , aa
                        [ Route.link
                            (Route.SelectProject Nothing)
                        ]
                        "your dashboard"
                    , text ". If you see the gripe you submitted within \"New\" gripes that means you've implemented Gripeless successfully! Amazing!"
                    ]
                , ha2 "Prefilling notification emails"
                , para "Gripeless can automatically send notifications to users whenever you complete their gripes. The email is optional for users to provide, but you can automatically prefill it through the SDK for their convenience."
                , para "To pass in the user's email use the second argument as follows:"
                , code <|
                    text
                        ("gripeless.modal('project-name', {\n"
                            ++ "  email: 'user@email.com'\n"
                            ++ "})"
                        )
                , paraRich
                    [ text "The email input on your SDK should dissappear and the text should change to "
                    , italic "'You will be notified by email when this issue gets fixed'"
                    , text "."
                    ]
                , paraRich
                    [ text "If the user is not logged in and you still have the gripeless button visible for them you can just pass in "
                    , term "undefined"
                    , text " as the email and the SDK will fallback to accepting the email from users."
                    ]
                , para "This feature nice for any website that has access to its user's emails and is entirely optional (but still highly recommended)."
                , ha2 "Prefilling the message"
                , para "In certain situations in your UI you might want to provide a default message that will fill the text input part of the modal."
                , paraRich [ text "To do that, simply pass in a ", term "message", text " with a string, like so:" ]
                , code <|
                    text
                        ("gripeless.modal('project-name', {\n"
                            ++ "  message: 'Default message content'\n"
                            ++ "})"
                        )
                , para "The message will always be shown if you provide one, even if the user had previously had cached some content of their own."
                , tip [ text "This feature is used in the Gripeless Dashboard to allow quick reports of incorrect page screenshots." ]
                , ha2 "Using a custom context"
                , paraRich [ text "A ", boldy "custom context", text " is an object with keys and string values allowing you to pass additional information to Gripeless whenever the gripe is submitted." ]
                , tip [ text "You can use custom context to pass information about the user of your app, which you can use to follow up with them if necessary." ]
                , para "This feature is entirely optional, but comes useful if you want to know more about e.g. the state of your app at the time of the submission."
                , code <|
                    text
                        ("gripeless.modal('project-name', {\n"
                            ++ "  context: {\n"
                            ++ "    userId: 'aGVsbG8hIDpdCg=='\n"
                            ++ "    theme: 'dark'\n"
                            ++ "  }\n"
                            ++ "})"
                        )
                , para "Note that you can only pass values that are strings, anything that's not a string will be coerced into one."
                , para "The amount of keys you can send is unlimited, but the more you send the less legible your dashboard will become."
                ]
            , div [ class "text-center text-gray-700 text-sm pb-8" ]
                [ button [ onClick OpenGripeless ] [ text "Report an issue" ] ]
            ]
        ]
    }
