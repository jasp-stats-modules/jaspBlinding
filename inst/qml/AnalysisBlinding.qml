import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import JASP
import JASP.Controls

Form {
    info: qsTr("Analysis blinding: mask or scramble variables to reduce confirmation bias. Build and debug your analysis pipeline on the blinded data, then unblind once the analysis is finalised.")

    // Remember the last save path across runs (jaspSyntheticData pattern).
    property string lastSavePath: (typeof analysisState !== "undefined" && analysisState.lastSavePath) ? analysisState.lastSavePath : ""

    VariablesForm {
        AvailableVariablesList { name: "allVariables" }

        AssignedVariablesList {
            name:            "variablesToBlind"
            label:           qsTr("Variables to blind")
            info:            qsTr("Variables that will be masked or scrambled. Select at least one variable to run the analysis.")
            allowedColumns:  ["scale", "ordinal", "nominal"]
        }

        AssignedVariablesList {
            name:            "groupingVariables"
            label:           qsTr("Grouping variables")
            info:            qsTr("Optional; used only by Scrambling. Scrambling is performed within each combination of these grouping variables.")
            allowedColumns:  ["ordinal", "nominal"]
            enabled:         scramblingRadio.checked && !byRowCheckBox.checked
        }
    }

    CheckBox {
        name: "showBlindedData"; label: qsTr("Show blinded data"); checked: true
        info:                       qsTr("Display a preview of the blinded data table. When checked, only the specified number of rows are shown. The full dataset is always exported to CSV regardless of this setting.")

        IntegerField {
            name:         "rowsToShow"
            label:        qsTr("Rows to show")
            defaultValue: 50
            min:          1
            info:         qsTr("Number of rows to display in the blinded data preview.")
        }
    }

    Section {
        title:    qsTr("Blinding method")
        columns:  1
        expanded: true

        RadioButtonGroup {
            name: "blindingMethod"

            RadioButton {
                id: scramblingRadio
                value: "scrambling"; label: qsTr("Scrambling"); checked: true
                info:                 qsTr("Randomises the order of the selected values, preserving the data distribution but breaking the row-wise pairing.")

                CheckBox {
                    name:  "keepRowsTogether"
                    label: qsTr("Keep rows together")
                    info:  qsTr("Scramble the selected variables as a block: the within-row pairing of the selected variables is preserved, but rows are permuted.")
                }

                CheckBox {
                    id:   byRowCheckBox
                    name: "byRow"
                    label: qsTr("By row (scramble horizontally)")
                    info:  qsTr("For each row, shuffle the values across the selected columns. Requires compatible column types. Overrides 'Keep rows together' and grouping variables.")
                }
            }

            RadioButton {
                value: "masking"; label: qsTr("Masking")
                info:                qsTr("Replaces categorical values with anonymous labels (e.g. control -> masked_group_01). Only character/factor columns are processed; numeric columns are skipped.")

                CheckBox {
                    name:  "sameMappingAcrossVariables"
                    label: qsTr("Same mapping across variables")
                    info:  qsTr("Use a single shared set of anonymous labels across all selected variables, rather than one set per variable.")
                }

                TextField {
                    name:         "maskPrefix"
                    label:        qsTr("Prefix")
                    defaultValue: "masked_group_"
                    info:         qsTr("Prefix used for the anonymous masked labels. Each unique value is assigned a label like 'prefix_01', 'prefix_02', etc.")
                }
            }

            RadioButton {
                value: "decoy"; label: qsTr("Decoy data")
                info:                 qsTr("Generates multiple simulated datasets that mimic the original data's distributions but impose a different cluster structure. The analyst receives all datasets without knowing which (if any) is the real one.")

                IntegerField {
                    name:         "decoyRep"
                    label:        qsTr("Simulated datasets")
                    defaultValue: 5
                    min:          1
                    info:         qsTr("Number of simulated datasets to generate.")
                }

                CheckBox {
                    name:  "decoyInsertTrueData"
                    label: qsTr("Include original dataset")
                    info:  qsTr("Insert the real dataset at a random position among the simulated ones. The analyst will not know which dataset is real.")
                }

                CheckBox {
                    name:  "decoySubsetData"
                    label: qsTr("Subset data")
                    info:  qsTr("Simulate only a subset of rows, embedding the result back into the full dataset. Useful when the clustering hypothesis concerns only part of the data.")

                    TextField {
                        name:         "decoyRowIndices"
                        label:        qsTr("Row indices")
                        placeholderText: qsTr("e.g. 1-100")
                        info:         qsTr("Row indices to simulate (comma-separated). Ranges supported, e.g. 1-100,150,200-250.")
                    }
                }

                IntegerField {
                    name:         "decoyNoClusters"
                    label:        qsTr("Number of clusters")
                    defaultValue: 0
                    min:          0
                    info:         qsTr("Number of clusters to impose per simulated dataset. Must be between 1 and the number of selected variables. Set to 0 for a random number between 1 and the number of variables.")
                }

                DoubleField {
                    name:         "decoyDiagProb"
                    label:        qsTr("Within-cluster edge probability")
                    defaultValue: 0.75
                    fieldWidth:   60
                    info:         qsTr("Probability of an edge between variables in the same cluster. Leave at 0.75 to use a random draw from 0.6–0.9.")
                }

                DoubleField {
                    name:         "decoyOffDiagProb"
                    label:        qsTr("Between-cluster edge probability")
                    defaultValue: 0.175
                    fieldWidth:   60
                    info:         qsTr("Probability of an edge between variables in different clusters. Leave at 0.175 to use a random draw from 0.05–0.3.")
                }
            }
        }

        CheckBox {
            name: "setSeed"; label: qsTr("Set seed"); checked: true
            info:               qsTr("Use a fixed random seed so the blinding is reproducible.")

            IntegerField {
                name:         "seed"
                label:        qsTr("Seed")
                defaultValue: 42
                min:          0
                info:         qsTr("Random seed used by the blinding operation.")
            }
        }
    }

    Section {
        title:    qsTr("Save blinded data")
        columns:  1
        expanded: true

        info:    qsTr("Save the blinded dataset to a CSV file. Set a file path (type it or browse) and re-run to write the file.")

        FileSelector {
            name:           "fileFull"
            label:          qsTr("Save as…")
            placeholderText: qsTr("blind_data.csv")
            filter:         "*.csv"
            save:           true
            value:          lastSavePath
            Layout.fillWidth: true
            info:           qsTr("Pick a file path (type it or browse) and re-run to write the CSV. The column headers in the exported file use the original (decoded) variable names.")
        }
    }
}
