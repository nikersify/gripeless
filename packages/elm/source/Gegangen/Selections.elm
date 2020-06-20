module Gegangen.Selections exposing
    ( checkoutSession
    , gripe
    , gripeDetailed
    , modalAppearance
    , onboarding
    , project
    , projectPlan
    , user
    )

import Api.Enum.OnboardingStep exposing (OnboardingStep)
import Api.Object
import Api.Object.CheckoutSession as CheckoutSession
import Api.Object.Device as Device
import Api.Object.FreePlan
import Api.Object.Gripe as Gripe
import Api.Object.GripeComment as GripeComment
import Api.Object.GripeCreatedEvent
import Api.Object.GripeStatusUpdatedEvent
import Api.Object.GripeTitleUpdatedEvent
import Api.Object.GrowthPlan as GrowthPlan
import Api.Object.ModalAppearance as ModalAppearance
import Api.Object.Project as Project
import Api.Object.User as User
import Api.Union.GripeTimelineItem
import Api.Union.Plan
import Gegangen.Models as Models
    exposing
        ( CheckoutSessionID
        , Device
        , Gripe
        , ModalAppearance
        , Plan
        , Project
        , User
        )
import Graphql.OptionalArgument exposing (OptionalArgument(..))
import Graphql.SelectionSet as SelectionSet
    exposing
        ( SelectionSet
        , map
        , map2
        , map3
        , map4
        , map6
        , map7
        , with
        )


user : SelectionSet User Api.Object.User
user =
    map4 User
        User.uid
        User.email
        User.name
        User.picture


gripe : SelectionSet Gripe Api.Object.Gripe
gripe =
    map7 Gripe
        Gripe.id
        Gripe.status
        Gripe.title
        Gripe.body
        Gripe.updated
        Gripe.hasNotification
        Gripe.created



-- platform : SelectionSet Platform Api.Object.Platform
-- platform =


device : SelectionSet Device Api.Object.Device
device =
    map7 Device
        Device.url
        Device.userAgent
        Device.viewportSize
        Device.browser
        Device.engine
        Device.os
        Device.platform


gripeDetailed : SelectionSet Models.GripeDetailed Api.Object.Gripe
gripeDetailed =
    SelectionSet.succeed Models.GripeDetailed
        |> with Gripe.id
        |> with Gripe.status
        |> with Gripe.title
        |> with Gripe.body
        |> with Gripe.imagePath
        |> with Gripe.context
        |> with Gripe.hasNotification
        |> with (Gripe.device device)
        |> with Gripe.created
        |> with
            (Gripe.timeline
                (Api.Union.GripeTimelineItem.fragments
                    { onGripeCreatedEvent =
                        map
                            Models.GripeCreatedEvent
                            Api.Object.GripeCreatedEvent.created
                    , onGripeStatusUpdatedEvent =
                        map
                            Models.GripeStatusUpdatedEvent
                            (map2 Models.GripeStatusUpdatedEventData
                                Api.Object.GripeStatusUpdatedEvent.created
                                Api.Object.GripeStatusUpdatedEvent.status
                            )
                    , onGripeTitleUpdatedEvent =
                        map
                            Models.GripeTitleUpdatedEvent
                            (map2 Models.GripeTitleUpdatedEventData
                                Api.Object.GripeTitleUpdatedEvent.created
                                Api.Object.GripeTitleUpdatedEvent.title
                            )
                    , onGripeComment =
                        map
                            Models.GripeTimelineComment
                            (map3 Models.GripeComment
                                GripeComment.id
                                GripeComment.body
                                GripeComment.created
                            )
                    }
                )
            )


project : SelectionSet Project Api.Object.Project
project =
    map3 Project
        Project.id
        Project.name
        Project.role


checkoutSession : SelectionSet CheckoutSessionID Api.Object.CheckoutSession
checkoutSession =
    CheckoutSession.id


onboarding : SelectionSet OnboardingStep Api.Object.Project
onboarding =
    Project.onboarding


projectPlan : SelectionSet Plan Api.Object.Project
projectPlan =
    Project.plan
        (Api.Union.Plan.fragments
            { onFreePlan = map Models.FreePlan Api.Object.FreePlan.since
            , onGrowthPlan =
                map Models.GrowthPlan
                    (map2
                        Models.GrowthPlanData
                        GrowthPlan.since
                        GrowthPlan.nextBilling
                    )
            }
        )


modalAppearance : SelectionSet ModalAppearance Api.Object.Project
modalAppearance =
    Project.modalAppearance
        (map ModalAppearance
            ModalAppearance.hasBranding
        )
