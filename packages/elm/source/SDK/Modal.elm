module SDK.Modal exposing (createGripeInputID, validateForm, view)

import Components
import File exposing (File)
import Gegangen exposing (formatError)
import Gegangen.Models exposing (ModalAppearance)
import Gegangen.Requests as Requests
import Graphql.OptionalArgument exposing (OptionalArgument(..))
import Html exposing (..)
import Html.Attributes exposing (accept, class, href, multiple, target, title, type_)
import Html.Events exposing (on, onClick, onSubmit, preventDefaultOn)
import Icons
import Json.Decode as Decode exposing (Decoder)
import RemoteData
import SDK.Capabilities exposing (hasBranding)
import SDK.FormData exposing (FormData)
import SDK.NotifyEmail as NotifyEmail exposing (NotifyEmail)
import SDK.Picture as Picture exposing (Picture(..))


type alias Model =
    { isMac : Bool
    , supportsScreenshots : Bool
    , formData : FormData
    , formValue : String
    , picture : Picture
    , notifyEmail : NotifyEmail
    , modalAppearanceData : Requests.ModalAppearanceResponse
    , hostname : String
    , open : Bool
    , isDemo : Bool
    , hoveringFile : Bool
    }


type alias Messages msg =
    { clearPicture : msg
    , clickedClose : msg
    , clickedSubmitAnother : msg
    , closeMsg : msg
    , fileHover : Bool -> msg
    , formSubmit : msg
    , gotFiles : List File -> msg
    , notifyEmailChanged : NotifyEmail -> msg
    , openPico : msg
    , updateFormValue : String -> msg
    }


hijackOn : String -> Decoder msg -> Html.Attribute msg
hijackOn event decoder =
    preventDefaultOn event (Decode.map hijack decoder)


hijack : msg -> ( msg, Bool )
hijack msg =
    ( msg, True )


dropDecoder : (List File -> msg) -> Decoder msg
dropDecoder gotFilesMsg =
    Decode.at
        [ "dataTransfer", "files" ]
        (Decode.index 0 File.decoder)
        |> Decode.andThen (\r -> Decode.succeed [ r ])
        |> Decode.map gotFilesMsg


filesDecoder : Decode.Decoder (List File)
filesDecoder =
    Decode.at [ "target", "files" ] (Decode.list File.decoder)


createGripeInputID : String
createGripeInputID =
    "create-gripe-input"


validateForm : String -> NotifyEmail -> Picture -> Bool
validateForm value notifyEmail picture =
    let
        length =
            String.length (String.trim value)
    in
    length
        > 0
        && length
        < 1024
        && NotifyEmail.isValid notifyEmail
        && Picture.isValid picture


fadeTransitionClass : Bool -> String -> String
fadeTransitionClass active opacity =
    "fade-transition-"
        ++ opacity
        ++ (if active then
                " active"

            else
                ""
           )


shift : Bool -> String
shift active =
    "shift-transition"
        ++ (if active then
                " active"

            else
                ""
           )


viewBackground : msg -> Bool -> Html msg
viewBackground closeMsg open =
    div
        [ class "inset-0 bg-gray-800 cursor-pointer absolute z-0"
        , class (fadeTransitionClass open "75")
        , onClick closeMsg
        ]
        []


viewFormSuccess : Messages msg -> Html msg
viewFormSuccess messages =
    div [ class "text-center" ]
        [ div [ class "text-center my-4 select-none" ]
            [ Icons.checkCircle "w-16 h-16 text-gray-500"
            , div [ class "text-gray-600 font-medium" ] [ text "Thank you!" ]
            ]
        , div [ class "mb-4 text-gray-800" ]
            [ p []
                [ text "Because of submissions like yours we're able to improve our product faster! "
                , text "If you have any more issues you'd like to let us know of, feel free to "
                , button
                    [ onClick messages.clickedSubmitAnother
                    , class "text-red-800"
                    ]
                    [ text "submit another issue" ]
                , text "."
                ]
            ]
        , div [ class "text-center mb-4" ]
            [ button
                [ onClick messages.clickedClose
                , class "border px-4 py-2 rounded mr-2 text-lg"
                , class "text-white bg-red-600 border-red-700 hover:bg-red-700"
                ]
                [ text "Dismiss" ]
            ]
        ]


viewDemoInformation : Html msg
viewDemoInformation =
    let
        bolded =
            \s -> span [ class "font-bold" ] [ text s ]

        italiano =
            \s -> span [ class "italic" ] [ text s ]
    in
    div [ class "bg-yellow-400 border border-yellow-500 mb-2 rounded-md p-2 text-yellow-900 text-sm" ]
        [ div [ class "flex" ]
            [ div [ class "flex-none" ] [ Icons.information "w-4 h-4 mr-2" ]
            , div []
                [ bolded "This is a demo modal"
                , text ", anything submitted through here will go to trash. If you want to report a real problem with this site, scroll down to the bottom and click on "
                , italiano "Report an Issue"
                , text "."
                ]
            ]
        ]


dropFileOverlay : Bool -> Html msg
dropFileOverlay show =
    div
        [ class "inset-0 absolute bg-gray-600 z-10 flex items-center justify-center select-none rounded-lg"
        , class "transition-opacity ease-out duration-200"
        , if show then
            class "opacity-75"

          else
            class "opacity-0 pointer-events-none"
        ]
        [ div
            [ class "inline-flex items-center text-white opacity-100" ]
            [ Icons.upload "w-6 h-6 mr-2", text "Upload image..." ]
        ]


viewFormInner :
    Messages msg
    -> Bool
    -> Bool
    -> String
    -> Bool
    -> Picture
    -> NotifyEmail
    -> Maybe ModalAppearance
    -> Html msg
viewFormInner messages isMac supportsScreenshots formValue isFormLoading picture notifyEmail maybeAppearance =
    let
        isFormValid =
            validateForm formValue notifyEmail picture

        canSubmit =
            isFormValid && not isFormLoading
    in
    div []
        [ h1 [ class "font-bold text-2xl mb-1 block" ] [ text "Submit an issue" ]
        , p [ class "text-gray-600 mb-4" ]
            [ text "Submit an annoyance, an issue or a problem about our product. We can only fix problems we know about!" ]
        , div [ class "mb-2" ]
            [ Components.viewTextarea
                { id = Just createGripeInputID
                , onInput = messages.updateFormValue
                , onSubmit = messages.formSubmit
                , classes = "font-medium"
                , isDisabled = isFormLoading
                , isMac = isMac
                , value = formValue
                , placeholder = "What's annoying?"
                }
            ]
        , div [ class "mb-3" ] [ NotifyEmail.view messages.notifyEmailChanged notifyEmail ]
        , div [ class "flex items-center -mx-4 -mb-4 bg-gray-200 p-4 rounded-b-lg" ]
            [ case picture of
                NoPicture ->
                    div
                        [ class "flex items-stretch" ]
                        [ if supportsScreenshots then
                            button
                                [ onClick messages.openPico
                                , type_ "button"
                                , class "border px-2 py-1 border-gray-400 bg-gray-300 rounded-l border-r-0 hover:bg-gray-400 text-gray-700 hover:text-gray-900 text-sm"
                                , class "flex items-center"
                                ]
                                [ Icons.camera "mr-1 w-4 h-4"
                                , text "Screenshot"
                                ]

                          else
                            text ""
                        , label
                            [ class "border px-2 py-2 border-gray-400 bg-gray-300 rounded-r hover:bg-gray-400 text-gray-700 hover:text-gray-900 cursor-pointer text-sm"
                            , if supportsScreenshots then
                                class "rounded-r"

                              else
                                class "rounded"
                            , class "flex items-center"
                            , title "Upload a file"
                            ]
                            [ input
                                [ type_ "file"
                                , multiple False
                                , accept ".jpg,.jpeg,.png,.tif,.bmp,.webp"
                                , on "change" (Decode.map messages.gotFiles filesDecoder)
                                , class "hidden"
                                ]
                                []
                            , Icons.upload "w-4 h-4"
                            ]
                        ]

                _ ->
                    Picture.view messages.clearPicture picture
            , div [ class "flex-grow flex justify-end items-center" ]
                [ if canSubmit then
                    Components.viewSubmitShortcutLabel isMac

                  else
                    text ""
                , Components.viewPrimaryButton "" { isDisabled = not canSubmit, isLoading = isFormLoading }
                ]
            ]
        ]


viewForm :
    Messages msg
    -> Bool
    -> Bool
    -> FormData
    -> String
    -> Picture
    -> NotifyEmail
    -> Maybe ModalAppearance
    -> Html msg
viewForm messages isMac supportsScreenshots formData formValue picture maybeEmail maybeAppearance =
    form [ onSubmit messages.formSubmit, class "mb-0" ]
        [ div
            [ class "absolute right-0 top-0" ]
            [ button [ onClick messages.clickedClose ] [ Icons.x "w-6 h-6 text-gray-600 mt-4 mr-4" ] ]
        , case formData of
            RemoteData.NotAsked ->
                viewFormInner
                    messages
                    isMac
                    supportsScreenshots
                    formValue
                    False
                    picture
                    maybeEmail
                    maybeAppearance

            RemoteData.Loading ->
                viewFormInner
                    messages
                    isMac
                    supportsScreenshots
                    formValue
                    True
                    picture
                    maybeEmail
                    maybeAppearance

            RemoteData.Failure error ->
                div [ class "text-red-500 font-bold text-sm" ]
                    [ text <| formatError error ]

            RemoteData.Success _ ->
                viewFormSuccess messages
        ]


viewModal : Messages msg -> Model -> Html msg
viewModal messages model =
    let
        theForm =
            viewForm
                messages
                model.isMac
                model.supportsScreenshots
                model.formData
                model.formValue
                model.picture
                model.notifyEmail
    in
    div
        [ class (shift model.open)
        , class "m-2 w-full sm:max-w-lg"
        , hijackOn "dragenter" (Decode.succeed (messages.fileHover True))
        , hijackOn "dragover" (Decode.succeed (messages.fileHover True))
        , hijackOn "dragleave" (Decode.succeed (messages.fileHover False))
        , hijackOn "drop" (dropDecoder messages.gotFiles)
        ]
        [ if model.isDemo then
            div [ class (fadeTransitionClass model.open "100") ] [ viewDemoInformation ]

          else
            text ""
        , div [ class "relative" ]
            [ dropFileOverlay model.hoveringFile
            , div
                [ class "rounded-lg bg-white shadow-lg border relative p-4 mb-1"
                , class "w-full sm:max-w-lg"
                , class (fadeTransitionClass model.open "100")
                ]
                [ case model.modalAppearanceData of
                    RemoteData.NotAsked ->
                        text ""

                    RemoteData.Failure error ->
                        text (formatError error)

                    RemoteData.Loading ->
                        theForm Nothing

                    RemoteData.Success appearance ->
                        theForm (Just appearance)
                ]
            ]
        , div [ class (fadeTransitionClass model.open "100") ]
            [ div
                [ class "text-right transition-opacity duration-200"
                , if hasBranding model.modalAppearanceData then
                    class "opacity-100 visible"

                  else
                    class "opacity-0 invisible"
                ]
                [ a
                    [ href ("https://" ++ model.hostname)
                    , target "_blank"
                    , class
                        "px-2 rounded inline-block bg-gray-700 text-gray-200 text-xs py-1 shadow hover:bg-gray-800"
                    ]
                    [ text "Powered by "
                    , span [ class "font-bold" ] [ text "Gripeless" ]
                    ]
                ]
            ]
        ]


view : Messages msg -> Model -> Html msg
view messages model =
    div [ class "fixed inset-0" ]
        [ div [ class "inset-0 flex absolute items-start sm:items-center justify-center" ]
            [ viewBackground messages.closeMsg model.open
            , viewModal messages model
            ]
        ]
