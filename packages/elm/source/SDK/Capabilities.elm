module SDK.Capabilities exposing (hasBranding)

import Gegangen.Requests as Requests
import RemoteData


hasBranding : Requests.ModalAppearanceResponse -> Bool
hasBranding =
    RemoteData.map .hasBranding >> RemoteData.withDefault False
