module Gegangen.Requests exposing
    ( CheckoutSessionResponse
    , GripeResponse
    , GripesResponse
    , GripesWithCountsResponse
    , IsProjectNameAvailableResponse
    , ModalAppearanceResponse
    , OnboardingResponse
    , OwnedProjectsResponse
    , PlanResponse
    , ProjectResponse
    , StringResponse
    , UserResponse
    , authenticated
    , claimProject
    , completeGripe
    , createCheckoutSession
    , createComment
    , createGripe
    , createProject
    , discardGripe
    , finishOnboarding
    , gripe
    , gripes
    , gripesWithCounts
    , isProjectNameAvailable
    , me
    , modalAppearance
    , onboarding
    , ownedProjects
    , project
    , projectPlan
    , restoreGripe
    , subscribeToBlogMailingList
    , subscribeToReminderMailingList
    , updateGripeTitle
    )

import Api.Enum.GripeStatus exposing (GripeStatus)
import Api.Enum.OnboardingStep exposing (OnboardingStep)
import Api.InputObject as InputObject
import Api.Mutation exposing (CreateCheckoutSessionRequiredArguments)
import Gegangen.Models
    exposing
        ( CheckoutSessionID
        , GripeDetailed
        , Gripes
        , GripesWithCounts
        , ModalAppearance
        , Plan
        , Project
        , ProjectNameAvailability
        , Projects
        , User
        )
import Gegangen.Mutations as Mutations
import Gegangen.Queries as Queries
import Graphql.Http
    exposing
        ( Error
        , Request
        , mutationRequest
        , queryRequest
        , send
        , withHeader
        , withTimeout
        )
import RemoteData exposing (RemoteData)
import ScalarCodecs exposing (GripeID)
import Token exposing (Token)



-- endpoint : String
-- endpoint =
--     "https://api.supers.localhost:5550"


noOp : Request decodesTo -> Request decodesTo
noOp request =
    request


withAuthHeader : Token -> Request decodesTo -> Request decodesTo
withAuthHeader token =
    case Token.unwrap token of
        Just auth ->
            withHeader "authorization" auth

        Nothing ->
            noOp


authenticated :
    Request decodesTo
    -> (RemoteData (Error decodesTo) decodesTo -> msg)
    -> Token
    -> Cmd msg
authenticated request msg token =
    withAuthHeader token request
        |> withTimeout 5000
        |> send (RemoteData.fromResult >> msg)


type alias GraphQLData object =
    RemoteData (Error object) object


type alias IsProjectNameAvailableResponse =
    GraphQLData ProjectNameAvailability


type alias StringResponse =
    GraphQLData String


type alias ProjectResponse =
    GraphQLData Project


type alias UserResponse =
    GraphQLData User


type alias GripesResponse =
    GraphQLData Gripes


type alias GripesWithCountsResponse =
    GraphQLData GripesWithCounts


type alias GripeResponse =
    GraphQLData GripeDetailed


type alias OwnedProjectsResponse =
    GraphQLData Projects


type alias CheckoutSessionResponse =
    GraphQLData CheckoutSessionID


type alias OnboardingResponse =
    GraphQLData OnboardingStep


type alias PlanResponse =
    GraphQLData Plan


type alias ModalAppearanceResponse =
    GraphQLData ModalAppearance


me : String -> (UserResponse -> msg) -> Token -> Cmd msg
me endpoint =
    authenticated (queryRequest endpoint Queries.me)


project : String -> String -> (ProjectResponse -> msg) -> Token -> Cmd msg
project endpoint projectName =
    authenticated (queryRequest endpoint (Queries.project projectName))


gripes : String -> String -> Maybe GripeStatus -> (GripesResponse -> msg) -> Token -> Cmd msg
gripes endpoint projectName maybeGripeStatus =
    authenticated (queryRequest endpoint (Queries.gripes projectName maybeGripeStatus))


gripesWithCounts : String -> String -> GripeStatus -> (GripesWithCountsResponse -> msg) -> Token -> Cmd msg
gripesWithCounts endpoint projectName gripeStatus =
    authenticated (queryRequest endpoint (Queries.gripesWithCounts projectName gripeStatus))


gripe : String -> GripeID -> (GripeResponse -> msg) -> Token -> Cmd msg
gripe endpoint gripeId =
    authenticated (queryRequest endpoint (Queries.gripeWithTimeline gripeId))


createGripe :
    String
    -> String
    -> InputObject.CreateGripeInput
    -> (GripeResponse -> msg)
    -> Token
    -> Cmd msg
createGripe endpoint projectName input =
    authenticated (mutationRequest endpoint (Mutations.createGripe projectName input))


updateGripeTitle : String -> GripeID -> String -> (GripeResponse -> msg) -> Token -> Cmd msg
updateGripeTitle endpoint id title =
    authenticated (mutationRequest endpoint (Mutations.updateGripeTitle id title))


createComment : String -> GripeID -> String -> (GripeResponse -> msg) -> Token -> Cmd msg
createComment endpoint gripeId body =
    authenticated (mutationRequest endpoint (Mutations.createComment gripeId body))


completeGripe : String -> GripeID -> (GripeResponse -> msg) -> Token -> Cmd msg
completeGripe endpoint id =
    authenticated (mutationRequest endpoint (Mutations.completeGripe id))


discardGripe : String -> GripeID -> (GripeResponse -> msg) -> Token -> Cmd msg
discardGripe endpoint id =
    authenticated (mutationRequest endpoint (Mutations.discardGripe id))


restoreGripe : String -> GripeID -> (GripeResponse -> msg) -> Token -> Cmd msg
restoreGripe endpoint id =
    authenticated (mutationRequest endpoint (Mutations.restoreGripe id))


ownedProjects : String -> (OwnedProjectsResponse -> msg) -> Token -> Cmd msg
ownedProjects endpoint =
    authenticated (queryRequest endpoint Queries.ownedProjects)


createCheckoutSession : String -> CreateCheckoutSessionRequiredArguments -> (CheckoutSessionResponse -> msg) -> Token -> Cmd msg
createCheckoutSession endpoint args =
    authenticated (mutationRequest endpoint (Mutations.createCheckoutSession args))


createProject : String -> String -> (ProjectResponse -> msg) -> Token -> Cmd msg
createProject endpoint projectName =
    authenticated (mutationRequest endpoint (Mutations.createProject projectName))


claimProject : String -> String -> (ProjectResponse -> msg) -> Token -> Cmd msg
claimProject endpoint key =
    authenticated (mutationRequest endpoint (Mutations.claimProject key))


isProjectNameAvailable : String -> String -> (IsProjectNameAvailableResponse -> msg) -> Token -> Cmd msg
isProjectNameAvailable endpoint projectName =
    authenticated (queryRequest endpoint (Queries.isProjectNameAvailable projectName))


onboarding : String -> String -> (OnboardingResponse -> msg) -> Token -> Cmd msg
onboarding endpoint projectName =
    authenticated (queryRequest endpoint (Queries.onboarding projectName))


finishOnboarding : String -> String -> (OnboardingResponse -> msg) -> Token -> Cmd msg
finishOnboarding endpoint projectName =
    authenticated (mutationRequest endpoint (Mutations.finishOnboarding projectName))


projectPlan : String -> String -> (PlanResponse -> msg) -> Token -> Cmd msg
projectPlan endpoint projectName =
    authenticated (queryRequest endpoint (Queries.projectPlan projectName))


modalAppearance : String -> String -> (ModalAppearanceResponse -> msg) -> Token -> Cmd msg
modalAppearance endpoint projectName =
    authenticated (queryRequest endpoint (Queries.modalAppearance projectName))


subscribeToBlogMailingList : String -> String -> (StringResponse -> msg) -> Token -> Cmd msg
subscribeToBlogMailingList endpoint email =
    authenticated (mutationRequest endpoint (Mutations.subscribeToBlogMailingList email))


subscribeToReminderMailingList : String -> String -> (StringResponse -> msg) -> Token -> Cmd msg
subscribeToReminderMailingList endpoint email =
    authenticated (mutationRequest endpoint (Mutations.subscribeToReminderMailingList email))
