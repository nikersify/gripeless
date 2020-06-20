module Gegangen.Models exposing
    ( CheckoutSessionID
    , Device
    , Gripe
    , GripeComment
    , GripeCounts
    , GripeCreatedEventData
    , GripeDetailed
    , GripeStatusUpdatedEventData
    , GripeTimelineItem(..)
    , GripeTitleUpdatedEventData
    , Gripes
    , GripesWithCounts
    , GrowthPlanData
    , ModalAppearance
    , Plan(..)
    , Project
    , ProjectNameAvailability
    , Projects
    , User
    )

import Api.Enum.GripeAction exposing (GripeAction)
import Api.Enum.GripeStatus exposing (GripeStatus)
import Api.Enum.Platform exposing (Platform)
import Api.Enum.ProjectRole exposing (ProjectRole)
import ScalarCodecs exposing (GripeID, KeyValueString, PosixTime)


type alias User =
    { uid : String
    , email : String
    , name : Maybe String
    , picture : Maybe String
    }


type alias Project =
    { id : String
    , name : String
    , role : ProjectRole
    }


type alias Projects =
    List Project


type alias Gripe =
    { id : GripeID
    , status : GripeStatus
    , title : Maybe String
    , body : String
    , updated : Maybe PosixTime
    , hasNotification : Bool
    , created : PosixTime
    }


type alias Gripes =
    List Gripe


type alias GripeCounts =
    { new : Int
    , unresolved : Int
    }


type alias GripesWithCounts =
    { counts : GripeCounts
    , gripes : Gripes
    }


type alias GripeComment =
    { id : String
    , body : String
    , created : PosixTime
    }


type alias Device =
    { url : Maybe String
    , userAgent : Maybe String
    , viewportSize : Maybe String
    , browser : Maybe String
    , engine : Maybe String
    , os : Maybe String
    , platform : Maybe Platform
    }


type alias GripeDetailed =
    { id : GripeID
    , status : GripeStatus
    , title : Maybe String
    , body : String
    , imagePath : Maybe String
    , context : List KeyValueString
    , hasNotification : Bool
    , device : Device
    , created : PosixTime
    , timeline : List GripeTimelineItem
    }


type alias GripeCreatedEventData =
    PosixTime


type alias GripeStatusUpdatedEventData =
    { created : PosixTime
    , status : GripeAction
    }


type alias GripeTitleUpdatedEventData =
    { created : PosixTime
    , title : String
    }


type GripeTimelineItem
    = GripeCreatedEvent GripeCreatedEventData
    | GripeStatusUpdatedEvent GripeStatusUpdatedEventData
    | GripeTitleUpdatedEvent GripeTitleUpdatedEventData
    | GripeTimelineComment GripeComment


type alias CheckoutSessionID =
    String


type alias ProjectNameAvailability =
    { name : String
    , isAvailable : Bool
    }


type alias ModalAppearance =
    { hasBranding : Bool }


type alias GrowthPlanData =
    { since : PosixTime
    , nextBilling : PosixTime
    }


type Plan
    = FreePlan PosixTime
    | GrowthPlan GrowthPlanData
