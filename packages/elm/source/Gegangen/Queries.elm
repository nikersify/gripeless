module Gegangen.Queries exposing
    ( gripe
    , gripeCounts
    , gripeWithTimeline
    , gripes
    , gripesWithCounts
    , isProjectNameAvailable
    , me
    , modalAppearance
    , onboarding
    , ownedProjects
    , project
    , projectPlan
    )

import Api.Enum.GripeStatus as GripeStatus exposing (GripeStatus)
import Api.Enum.OnboardingStep exposing (OnboardingStep)
import Api.Object.ProjectNameAvailability as ProjectNameAvailability
import Api.Query as Query
import Gegangen.Models
    exposing
        ( Gripe
        , GripeCounts
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
import Gegangen.Selections as Selections
import Graphql.Operation exposing (RootQuery)
import Graphql.OptionalArgument exposing (OptionalArgument(..))
import Graphql.SelectionSet as SelectionSet exposing (SelectionSet)
import ScalarCodecs exposing (GripeID)


me : SelectionSet User RootQuery
me =
    Query.me Selections.user


project : String -> SelectionSet Project RootQuery
project projectName =
    Query.project { name = projectName } Selections.project


gripes : String -> Maybe GripeStatus -> SelectionSet Gripes RootQuery
gripes projectName maybeGripeStatus =
    Query.gripes
        (\optionals ->
            { optionals
                | status =
                    Maybe.withDefault Absent
                        (Maybe.map Present maybeGripeStatus)
            }
        )
        { projectName = projectName }
        Selections.gripe


gripeCount : String -> GripeStatus -> SelectionSet Int RootQuery
gripeCount projectName status =
    Query.gripesCount
        (\optionals ->
            { optionals | status = Present status }
        )
        { projectName = projectName }


gripeCounts : String -> SelectionSet GripeCounts RootQuery
gripeCounts projectName =
    SelectionSet.map2 GripeCounts
        (gripeCount projectName GripeStatus.New)
        (gripeCount projectName GripeStatus.Actionable)


gripesWithCounts : String -> GripeStatus -> SelectionSet GripesWithCounts RootQuery
gripesWithCounts projectName gripeStatus =
    SelectionSet.map2 GripesWithCounts
        (gripeCounts projectName)
        (gripes projectName (Just gripeStatus))


gripe : GripeID -> SelectionSet Gripe RootQuery
gripe gripeID =
    Query.gripe { id = gripeID } Selections.gripe


gripeWithTimeline : GripeID -> SelectionSet GripeDetailed RootQuery
gripeWithTimeline gripeID =
    Query.gripe { id = gripeID } Selections.gripeDetailed


ownedProjects : SelectionSet Projects RootQuery
ownedProjects =
    Query.ownedProjects Selections.project


isProjectNameAvailable : String -> SelectionSet ProjectNameAvailability RootQuery
isProjectNameAvailable name =
    Query.isProjectNameAvailable { name = name }
        (SelectionSet.map2 ProjectNameAvailability
            ProjectNameAvailability.name
            ProjectNameAvailability.isAvailable
        )


onboarding : String -> SelectionSet OnboardingStep RootQuery
onboarding projectName =
    Query.project { name = projectName } Selections.onboarding


projectPlan : String -> SelectionSet Plan RootQuery
projectPlan projectName =
    Query.project { name = projectName } Selections.projectPlan


modalAppearance : String -> SelectionSet ModalAppearance RootQuery
modalAppearance projectName =
    Query.project { name = projectName } Selections.modalAppearance
