module Gegangen.Mutations exposing
    ( claimProject
    , completeGripe
    , createCheckoutSession
    , createComment
    , createGripe
    , createProject
    , discardGripe
    , finishOnboarding
    , restoreGripe
    , subscribeToBlogMailingList
    , subscribeToReminderMailingList
    , updateGripeTitle
    )

import Api.Enum.OnboardingStep exposing (OnboardingStep)
import Api.InputObject as InputObject
import Api.Mutation as Mutation exposing (CreateCheckoutSessionRequiredArguments)
import Gegangen.Models
    exposing
        ( CheckoutSessionID
        , GripeDetailed
        , Project
        )
import Gegangen.Selections as Selections
import Graphql.Operation exposing (RootMutation)
import Graphql.SelectionSet exposing (SelectionSet)
import ScalarCodecs exposing (GripeID)


createGripe : String -> InputObject.CreateGripeInput -> SelectionSet GripeDetailed RootMutation
createGripe projectName gripe =
    Mutation.createGripe
        { projectName = projectName, gripe = gripe }
        Selections.gripeDetailed


updateGripeTitle : GripeID -> String -> SelectionSet GripeDetailed RootMutation
updateGripeTitle id title =
    Mutation.updateGripeTitle
        { id = id, title = title }
        Selections.gripeDetailed


createComment : GripeID -> String -> SelectionSet GripeDetailed RootMutation
createComment gripeId body =
    Mutation.createGripeComment { gripeId = gripeId, body = body } Selections.gripeDetailed


completeGripe : GripeID -> SelectionSet GripeDetailed RootMutation
completeGripe id =
    Mutation.completeGripe { id = id } Selections.gripeDetailed


discardGripe : GripeID -> SelectionSet GripeDetailed RootMutation
discardGripe id =
    Mutation.discardGripe { id = id } Selections.gripeDetailed


restoreGripe : GripeID -> SelectionSet GripeDetailed RootMutation
restoreGripe id =
    Mutation.restoreGripe { id = id } Selections.gripeDetailed


createCheckoutSession : CreateCheckoutSessionRequiredArguments -> SelectionSet CheckoutSessionID RootMutation
createCheckoutSession args =
    Mutation.createCheckoutSession
        args
        Selections.checkoutSession


createProject : String -> SelectionSet Project RootMutation
createProject projectName =
    Mutation.createProject { projectName = projectName } Selections.project


claimProject : String -> SelectionSet Project RootMutation
claimProject key =
    Mutation.claimProject { key = key } Selections.project


finishOnboarding : String -> SelectionSet OnboardingStep RootMutation
finishOnboarding projectName =
    Mutation.finishOnboarding { projectName = projectName } Selections.onboarding


subscribeToBlogMailingList : String -> SelectionSet String RootMutation
subscribeToBlogMailingList email =
    Mutation.subscribeToBlogMailingList { email = email }


subscribeToReminderMailingList : String -> SelectionSet String RootMutation
subscribeToReminderMailingList email =
    Mutation.subscribeToReminderMailingList { email = email }
