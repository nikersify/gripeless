port module Entry.SDK exposing (main)

import Api.InputObject exposing (buildCreateGripeInput)
import Browser
import File exposing (File)
import Gegangen.Requests as Requests
import Graphql.OptionalArgument exposing (OptionalArgument(..))
import Html exposing (..)
import Http
import Json.Decode as Decode exposing (Decoder, decodeValue)
import Json.Encode as Encode
import Rectangle exposing (Rectangle)
import RemoteData
import SDK.FormData exposing (FormData)
import SDK.Modal as Modal
import SDK.NotifyEmail as NotifyEmail exposing (NotifyEmail)
import SDK.Pico as Pico
import SDK.Picture as Picture exposing (Picture(..))
import Task
import Token
import Url.Builder


port close : () -> Cmd msg


port aboutToClose : () -> Cmd msg


port focus : String -> Cmd msg


port keyUp : (String -> msg) -> Sub msg


port cacheBody : String -> Cmd msg


port cacheNotifyEmail : Maybe String -> Cmd msg


port gotGeneratedScreenshot : (Encode.Value -> msg) -> Sub msg


port gotGeneratedScreenshotError : (String -> msg) -> Sub msg


port generateScreenshot : Rectangle -> Cmd msg



-- MODEL


type alias Context =
    List ( String, String )


type View
    = Pico Pico.Model
    | Form


type alias Model =
    { -- Session
      projectName : String
    , modalAppearanceData : Requests.ModalAppearanceResponse
    , context : Context
    , url : String
    , viewportSize : String
    , isDemo : Bool
    , isMac : Bool
    , supportsScreenshots : Bool
    , hostname : String
    , apiURL : String
    , open : Bool

    -- Form values
    , formData : FormData
    , formValue : String
    , picture : Picture
    , notifyEmail : NotifyEmail

    -- Form view
    , hoveringFile : Bool
    , view : View
    }


type alias Flags =
    { projectName : String
    , message : Maybe String
    , url : String
    , isDemo : Bool
    , isMac : Bool
    , supportsScreenshots : Bool
    , hostname : String
    , cachedBody : Maybe String
    , apiURL : String
    , context : Context
    , viewportSize : String
    , notifyEmail : ( Maybe String, Maybe String )
    }



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- INIT


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        ( m, c ) =
            loadModalAppearance flags.projectName
                { view = Form
                , projectName = flags.projectName
                , modalAppearanceData = RemoteData.NotAsked
                , isDemo = flags.isDemo
                , isMac = flags.isMac
                , supportsScreenshots = flags.supportsScreenshots
                , hostname = flags.hostname
                , apiURL = flags.apiURL
                , context = flags.context
                , url = flags.url
                , viewportSize = flags.viewportSize
                , formValue =
                    Maybe.withDefault
                        (Maybe.withDefault "" flags.cachedBody)
                        flags.message
                , formData = RemoteData.NotAsked
                , picture = Picture.init
                , open = True
                , hoveringFile = False
                , notifyEmail =
                    case flags.notifyEmail of
                        ( Just cachedEmail, Nothing ) ->
                            NotifyEmail.initEditing cachedEmail

                        ( Nothing, Just prefilledEmail ) ->
                            NotifyEmail.initPrefilled prefilledEmail

                        ( Just _, Just prefilledEmail ) ->
                            NotifyEmail.initPrefilled prefilledEmail

                        ( Nothing, Nothing ) ->
                            NotifyEmail.initEmpty
                }
    in
    ( m, Cmd.batch [ c, focus Modal.createGripeInputID ] )


loadModalAppearance : String -> Model -> ( Model, Cmd Msg )
loadModalAppearance projectName model =
    ( { model | modalAppearanceData = RemoteData.Loading }
    , Requests.modalAppearance
        model.apiURL
        projectName
        GotModalAppearanceResponse
        Token.empty
    )



-- UPDATE


type Msg
    = NoOp
    | PicoMsg Pico.Msg
    | OpenPico
    | GotModalAppearanceResponse Requests.ModalAppearanceResponse
    | GotCreateGripeResponse Requests.GripeResponse
    | GotGeneratedScreenshot (Result String File)
    | ClickedClose
    | GotFiles (List File)
    | GotPreview File String
    | GotProgress Http.Progress
    | ImageUploaded File (Result Http.Error String)
    | FileHover Bool
    | NotifyEmailChanged NotifyEmail
    | UpdateFormValue String
    | ClickedSubmitAnother
    | ClearPicture
    | FormSubmit


decodeUploadImageResponseId : Decoder String
decodeUploadImageResponseId =
    Decode.field "id" Decode.string


formatHttpError : Http.Error -> String
formatHttpError error =
    case error of
        Http.BadUrl s ->
            "Bad url: " ++ s

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad status: " ++ String.fromInt status

        Http.BadBody reason ->
            "Bad request: " ++ reason


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        PicoMsg picoMsg ->
            case model.view of
                Form ->
                    ( model, Cmd.none )

                Pico picoModel ->
                    case picoMsg of
                        Pico.ExternalMsg externalMsg ->
                            handlePicoExternalMsg externalMsg model

                        _ ->
                            let
                                ( newModel, cmd ) =
                                    Pico.update picoMsg picoModel
                            in
                            ( { model | view = Pico newModel }, Cmd.map PicoMsg cmd )

        OpenPico ->
            let
                ( picoModel, picoCmd ) =
                    Pico.init
            in
            ( { model | view = Pico picoModel }, Cmd.map PicoMsg picoCmd )

        GotModalAppearanceResponse response ->
            ( { model | modalAppearanceData = response }, Cmd.none )

        GotCreateGripeResponse response ->
            let
                newFormValue =
                    case response of
                        RemoteData.Success _ ->
                            ""

                        _ ->
                            model.formValue
            in
            ( { model
                | formData = response
                , formValue =
                    newFormValue
              }
            , cacheBody newFormValue
            )

        GotGeneratedScreenshot result ->
            case result of
                Result.Err error ->
                    ( { model | picture = Picture.FailedPicture error }
                    , Cmd.none
                    )

                Result.Ok file ->
                    handleGotFiles [ file ] model

        ClearPicture ->
            ( { model | picture = Picture.init }, Cmd.none )

        GotFiles files ->
            handleGotFiles files model

        GotProgress progress ->
            case ( model.picture, progress ) of
                ( UploadingPicture ( f, pr, _ ), Http.Sending p ) ->
                    ( { model
                        | picture = UploadingPicture ( f, pr, Http.fractionSent p )
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ImageUploaded ourFile result ->
            case result of
                Result.Ok id ->
                    case model.picture of
                        UploadingPicture ( theirFile, maybePreview, _ ) ->
                            if ourFile == theirFile then
                                ( { model | picture = UploadedPicture ( theirFile, maybePreview, id ) }
                                , Cmd.none
                                )

                            else
                                ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Result.Err err ->
                    ( { model
                        | picture = FailedPicture (formatHttpError err)
                      }
                    , Cmd.none
                    )

        GotPreview ourFile preview ->
            case model.picture of
                UploadingPicture ( theirFile, _, progress ) ->
                    if ourFile == theirFile then
                        ( { model | picture = UploadingPicture ( theirFile, Just preview, progress ) }
                        , Cmd.none
                        )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        UpdateFormValue formValue ->
            ( { model
                | formValue = formValue
                , formData = RemoteData.NotAsked
              }
            , cacheBody formValue
            )

        FormSubmit ->
            if
                Modal.validateForm
                    model.formValue
                    model.notifyEmail
                    model.picture
            then
                ( { model | formData = RemoteData.Loading }
                , Requests.createGripe
                    model.apiURL
                    model.projectName
                    (buildCreateGripeInput
                        { body = model.formValue
                        , context = model.context
                        }
                        (\_ ->
                            { url = Present model.url
                            , viewportSize = Present model.viewportSize
                            , notifyEmail = NotifyEmail.toOptionalArgument model.notifyEmail
                            , imageId =
                                Picture.toOptionalArgument model.picture
                            }
                        )
                    )
                    GotCreateGripeResponse
                    Token.empty
                )

            else
                ( model, Cmd.none )

        ClickedSubmitAnother ->
            ( { model
                | formData = RemoteData.NotAsked
                , picture = Picture.init
              }
            , focus Modal.createGripeInputID
            )

        ClickedClose ->
            ( { model | open = False }
            , aboutToClose ()
            )

        FileHover b ->
            ( { model | hoveringFile = b }, Cmd.none )

        NotifyEmailChanged notifyEmail ->
            ( { model | notifyEmail = notifyEmail }
            , Cmd.batch
                [ focus NotifyEmail.inputID
                , cacheNotifyEmail (NotifyEmail.getIfEditing notifyEmail)
                ]
            )


handlePicoExternalMsg : Pico.ExternalMsg -> Model -> ( Model, Cmd Msg )
handlePicoExternalMsg externalMsg model =
    case externalMsg of
        Pico.Abort ->
            ( { model | view = Form }
            , focus Modal.createGripeInputID
            )

        Pico.ConfirmedSelecting rectangle ->
            ( { model
                | view = Form
                , picture = Picture.preparing
              }
            , generateScreenshot rectangle
            )


handleGotFiles : List File -> Model -> ( Model, Cmd Msg )
handleGotFiles files model =
    (case files of
        [ file ] ->
            ( { model | picture = UploadingPicture ( file, Nothing, 0.0 ) }
            , Cmd.batch
                [ Task.perform (GotPreview file) (File.toUrl file)
                , Http.request
                    { method = "POST"
                    , url = Url.Builder.crossOrigin model.apiURL [ "upload", "image" ] []
                    , headers = []
                    , body = Http.multipartBody [ Http.filePart "image" file ]
                    , expect = Http.expectJson (ImageUploaded file) decodeUploadImageResponseId
                    , timeout = Just 60000
                    , tracker = Just "upload"
                    }
                ]
            )

        _ ->
            ( { model | picture = Picture.init }, Cmd.none )
    )
        |> Tuple.mapFirst (\m -> { m | hoveringFile = False })



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Http.track "upload" GotProgress
        , -- Not using Browser.Events.onKeyDown since this code runs in the
          -- outside document in the embed
          keyUp
            (\key ->
                case ( key, model.view ) of
                    ( "Escape", Form ) ->
                        ClickedClose

                    ( "Escape", Pico _ ) ->
                        PicoMsg (Pico.ExternalMsg Pico.Abort)

                    _ ->
                        NoOp
            )
        , gotGeneratedScreenshotError (\err -> GotGeneratedScreenshot (Result.Err err))
        , gotGeneratedScreenshot
            (\value ->
                case decodeValue File.decoder value of
                    Err _ ->
                        GotGeneratedScreenshot
                            (Result.Err "Failed to decode screenshot file")

                    Ok file ->
                        GotGeneratedScreenshot (Result.Ok file)
            )
        , case model.view of
            Form ->
                Sub.none

            Pico picoModel ->
                Sub.map PicoMsg (Pico.subscriptions picoModel)
        ]



-- VIEW


view : Model -> Html Msg
view model =
    case model.view of
        Form ->
            Modal.view
                { clearPicture = ClearPicture
                , clickedClose = ClickedClose
                , clickedSubmitAnother = ClickedSubmitAnother
                , closeMsg = ClickedClose
                , fileHover = FileHover
                , formSubmit = FormSubmit
                , gotFiles = GotFiles
                , notifyEmailChanged = NotifyEmailChanged
                , openPico = OpenPico
                , updateFormValue = UpdateFormValue
                }
                { isMac = model.isMac
                , supportsScreenshots = model.supportsScreenshots
                , formData = model.formData
                , formValue = model.formValue
                , picture = model.picture
                , notifyEmail = model.notifyEmail
                , modalAppearanceData = model.modalAppearanceData
                , hostname = model.hostname
                , open = model.open
                , isDemo = model.isDemo
                , hoveringFile = model.hoveringFile
                }

        Pico pico ->
            Html.map PicoMsg (Pico.view pico)
