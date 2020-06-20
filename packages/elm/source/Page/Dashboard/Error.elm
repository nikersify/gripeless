module Page.Dashboard.Error exposing (view)

import DashboardPage exposing (DashboardPage)
import Html exposing (..)
import Session exposing (Session)


type alias Model =
    { session : Session
    , error : String
    }


view : Model -> DashboardPage msg
view model =
    text "wybuchuo"
