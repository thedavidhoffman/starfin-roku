'-------------------------------------------------------------------------------
' Color Values
'-------------------------------------------------------------------------------
' Use numeric hex values, such as &h12112BFF, when assigning colors directly to
' SceneGraph node fields from BrightScript, such as Rectangle.color or
' Label.color. Use string hex values, such as "0x292836FF", only for APIs that
' explicitly expect color strings. Roku standard dialog palette fields are one
' example of that string-based format.

' Note, this is NOT built out to the spec that I want it to be.
' It's barely a thing in its current state.

'-------------------------------------------------------------------------------
' Color
'-------------------------------------------------------------------------------
function Color(themeName = "Default" as string) as object
    if themeName = "Default" then return ThemeDefault()

    return ThemeDefault()
end function

'-------------------------------------------------------------------------------
' ThemeDefault
'-------------------------------------------------------------------------------
function ThemeDefault() as object

    BACKGROUND_PRIMARY = &h292836FF
    BACKGROUND_SECONDARY = &h313040FF

    return {
        background: {
            header: &h12112BFF
            primary: &h313040FF
            secondary: &h292836FF
            tertiary: &h12112BFF
        }
        text: {
            heading: &hF3F7FBFF
            primary: &hD5E0EAFF
            secondary: &hA8B7C8FF
        }
        accent: {
            primary: &hE09B42FF
            success: &h3BB273FF
            focus: &hFFFFFFFF
            divider: &hF3F7FB33
        }
        control: {
            input: &h16263BFF
            inputFocus: &h21405EFF
            badge: &h0F1A2AFF
            menu: &h132235FF
        }
        images: {
            button: {
                primaryFocused: "pkg:/images/buttons/primary_focused.9.png"
                primaryUnfocused: "pkg:/images/buttons/primary_unfocused.9.png"
                headerActive: "pkg:/images/buttons/header_active.9.png"
                headerFocused: "pkg:/images/buttons/header_focused.9.png"
            }
            badge: {
                audio: "pkg:/images/badges/audio_badge.9.png"
            }
            focus: {
                transparentFootprint: "pkg:/images/focus/transparent_focus_footprint.9.png"
            }
        }
        dialog: {
            backdrop: BACKGROUND_SECONDARY
            background: BACKGROUND_PRIMARY
        }
    }
end function
