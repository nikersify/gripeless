module DashboardPage exposing (DashboardPage, empty, mapMsg)

import Html exposing (Html, text)


type alias DashboardPage msg =
    { title : String
    , sidebar : List (Html msg)
    , body : Html msg
    }


empty : DashboardPage Never
empty =
    { title = "", body = text "", sidebar = [ text "" ] }


mapMsg : (msg -> newMsg) -> DashboardPage msg -> DashboardPage newMsg
mapMsg msg { title, sidebar, body } =
    { title = title
    , sidebar = List.map (Html.map msg) sidebar
    , body = Html.map msg body
    }
