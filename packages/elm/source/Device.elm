module Device exposing (Device, DeviceMeta, encode, isDesktop, isMac)


type Device
    = PC
    | Mac
    | Mobile


type alias DeviceMeta =
    { isDesktop : Bool
    , isMac : Bool
    }


isMac : Device -> Bool
isMac device =
    case device of
        Mac ->
            True

        _ ->
            False


isDesktop : Device -> Bool
isDesktop device =
    case device of
        PC ->
            True

        Mac ->
            True

        Mobile ->
            False


encode : DeviceMeta -> Device
encode meta =
    if meta.isMac then
        Mac

    else if meta.isDesktop then
        PC

    else
        Mobile
