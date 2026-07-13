import QtQuick
import JASP.Module

Description {
    name        : "jaspBlinding"
    title       : qsTr("Blinding")
    description : qsTr("Analysis blinding (masking and scrambling) to reduce confirmation bias.")
    version     : "0.1.0"
    author      : "JASP Team"
    maintainer  : "JASP Team <info@jasp-stats.org>"
    website     : "https://jasp-stats.org"
    license     : "GPL (>= 2)"
    icon        : "blinding.svg"
    requiresData: true
    preloadData : true

    Analysis {
        title: qsTr("Analysis Blinding")
        menu:  qsTr("Analysis Blinding")
        func:  "analysisBlinding"
        qml:   "AnalysisBlinding.qml"
        requiresData: true
    }
}
