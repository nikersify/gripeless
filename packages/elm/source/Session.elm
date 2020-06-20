module Session exposing (Session, init, updateNow, updateUser, updateZone)

import Browser.Navigation as Nav
import Device exposing (Device)
import Resources exposing (Resources)
import Time exposing (Posix)
import UserData exposing (UserDiffed)


type alias Session =
    { user : UserDiffed
    , key : Nav.Key
    , host : String
    , device : Device
    , now : Maybe Time.Posix
    , zone : Maybe Time.Zone
    , gripelessProjectName : String
    , demoProjectName : String
    , supportEmail : String
    , apiURL : String
    , sdkURL : String
    , resources : Resources
    }


init :
    { key : Nav.Key
    , host : String
    , device : Device
    , gripelessProjectName : String
    , demoProjectName : String
    , supportEmail : String
    , apiURL : String
    , sdkURL : String
    , resources : Resources
    }
    -> Session
init args =
    { host = args.host
    , device = args.device
    , key = args.key
    , gripelessProjectName = args.gripelessProjectName
    , demoProjectName = args.demoProjectName
    , supportEmail = args.supportEmail
    , resources = args.resources
    , apiURL = args.apiURL
    , sdkURL = args.sdkURL
    , user = UserData.Loading
    , now = Nothing
    , zone = Nothing
    }


updateUser : Session -> UserDiffed -> Session
updateUser session user =
    { session | user = user }


updateNow : Session -> Posix -> Session
updateNow session time =
    { session | now = Just time }


updateZone : Session -> Time.Zone -> Session
updateZone session zone =
    { session | zone = Just zone }
