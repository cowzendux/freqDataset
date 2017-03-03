* Encoding: UTF-8.
* Python function to calculate frequencies and put them in a dataset
* by Jamie DeCoster

***********
**** Usage: freqDataset(varList, [datasetName], [datasetLabels])
***********
**** var is a list of strings indicating the names of the variables whose 
* frequencies you want to calculate.
**** datasetName the name of the SPSS dataset you want to hold the 
* frequencies. By default, the name of the dataset is "Frequencies".
**** "datasetLabels" is an optional argument that identifies a list of
* strings identifying values that would be applied to the dataset. 
* This can be useful if you are appending the results 
* from multiple analyses to the same dataset.

*********
* Example
*********
* freqDataset(varList = ["race", "gender", "grade"],
datasetName = "Demographics",
datasetLabels = ["Fall", "2016"])
* This would calculate the frequencies for race, gender, and grade, and
* then put the results in a dataset named "Demographics". There would
* be variables in the Demographics data set for the variable, the value,
* the frequency corresponding to the value, and two labels. For 
* all of the cases added by this command, the value of the first label would
* be "Fall" and the value of the second label would be "2016".

*******
* Version History
*******
* 2016-12-02 Created
* 2016-12-02a Modified to work with crosstabs
* 2016-12-02b Added combinations of extra variables
* 2016-12-03 Obtained levels of first variable separately for 
*    each combination of the other variables

set printback off.
begin program python.
import spss, spssaux

def getVariableIndex(variable):
   	for t in range(spss.GetVariableCount()):
      if (variable.upper() == spss.GetVariableName(t).upper()):
         return(t)

def product(ar_list):
    if not ar_list:
        yield ()
    else:
        for a in ar_list[0]:
            for prod in product(ar_list[1:]):
                yield (a,)+prod

def freqDataset(varList, datasetName = "Frequencies", datasetLabels =  []):
#####
# Obtain a list of all the possible values
#####
# Use the OMS to pull the values from the frequencies command
    varLevels = []
    for var in varList:
        submitstring = """SET Tnumbers=values.
OMS SELECT TABLES
/IF COMMANDs=['Frequencies'] SUBTYPES=['Frequencies']
/DESTINATION FORMAT=OXML XMLWORKSPACE='freq_table'.
FREQUENCIES VARIABLES=%s.
OMSEND.

SET Tnumbers=Labels.""" %(var)
        spss.Submit(submitstring)
 
        handle='freq_table'
        context="/outputTree"
#get rows that are totals by looking for varName attribute
#use the group element to skip split file category text attributes
        xpath="//group/category[@varName]/@text"
        values=spss.EvaluateXPath(handle,context,xpath)
        varLevels.append(values)
        
######
# Identify combinations of later variables
######

    if (len(varList) == 1):
        comboNum = 1
        valueList = []
    else:
        comboNum = 1
        for t in range(len(varList) - 1):
            comboNum = comboNum*len(varLevels[t + 1])
        valueList = list(product(varLevels[1:]))

##########
# Obtain frequencies & percentages for first variable 
##########
    for combo in range(comboNum):
        if (comboNum > 1):
            submitstring = """USE ALL.
COMPUTE filter_$=("""
            for v in range(1, len(varList)):
                varIndex = getVariableIndex(varList[v])
                submitstring += "\n" + varList[v] + "=" 
                if (spss.GetVariableType(varIndex) == 0):
                    submitstring += valueList[combo][v-1]
                else:
                    submitstring += "'" + valueList[combo][v-1] + "'"
                if (v == len(varList)-1):
                    submitstring += """).
FILTER BY filter_$.
EXECUTE."""
                else:
                    submitstring += " and"
            print submitstring
            spss.Submit(submitstring)

    # Values of main variable within combination
    # Use the OMS to pull the values from the frequencies command
        var = varList[0]
        submitstring = """SET Tnumbers=values.
OMS SELECT TABLES
/IF COMMANDs=['Frequencies'] SUBTYPES=['Frequencies']
/DESTINATION FORMAT=OXML XMLWORKSPACE='freq_table'.
FREQUENCIES VARIABLES=%s.
OMSEND.

SET Tnumbers=Labels.""" %(var)
        spss.Submit(submitstring)
 
        handle='freq_table'
        context="/outputTree"
#get rows that are totals by looking for varName attribute
#use the group element to skip split file category text attributes
        xpath="//group/category[@varName]/@text"
        curvalues=spss.EvaluateXPath(handle,context,xpath)

        cmd = """FREQUENCIES VARIABLES={0}
  /ORDER=ANALYSIS.""".format(varList[0])
        handle,failcode=spssaux.CreateXMLOutput(
    		cmd,
    		omsid="Frequencies",
    		subtype="Frequencies",
    		visible=False)
        result=spssaux.GetValuesFromXMLWorkspace(
    		handle,
    		tableSubtype="Frequencies",
    		cellAttrib="text")

        fList = []
        pList = []
        vpList = []
        cpList = []
        for v in range(len(curvalues)):
            fList.append(int(float(result[v*4])))
            pList.append(float(result[v*4 + 1]))
            vpList.append(float(result[v*4 +2]))
            cpList.append(float(result[v*4 +3]))
        spss.Submit("use all.")

#########
# Write to data set
#########

# Determine active data set so we can return to it when finished
        activeName = spss.ActiveDataset()
# Set up data set if it doesn't already exist
        tag,err = spssaux.createXmlOutput('Dataset Display',
omsid='Dataset Display', subtype='Datasets')
        datasetList = spssaux.getValuesFromXmlWorkspace(tag, 'Datasets')

        if (datasetName not in datasetList):
            spss.StartDataStep()
            datasetObj = spss.Dataset(name=None)
            dsetname = datasetObj.name
            for var in varList:
                datasetObj.varlist.append(var, 50)
            datasetObj.varlist.append("N", 0)
            datasetObj.varlist.append("percent", 0)
            datasetObj.varlist.append("validpercent", 0)
            datasetObj.varlist.append("cumulativepercent", 0)
            spss.EndDataStep()
            submitstring = """dataset activate {0}.
dataset name {1}.""".format(dsetname, datasetName)
            spss.Submit(submitstring)

            spss.StartDataStep()
            datasetObj = spss.Dataset(name = datasetName)
            spss.SetActive(datasetObj)
    
    # Label variables
            variableList =[]
            for t in range(spss.GetVariableCount()):
                variableList.append(spss.GetVariableName(t))
            for t in range(len(datasetLabels)):
                if ("label{0}".format(str(t)) not in variableList):
                    datasetObj.varlist.append("label{0}".format(str(t)), 50)
            spss.EndDataStep()

# Alter numeric variable types
            submitstring = """alter type N (f8.0).
    alter type percent validpercent cumulativepercent (f8.1)."""
            spss.Submit(submitstring)

# Determine values for dataset
        dataValues = []
        for t in range(len(curvalues)):
            rowList = [curvalues[t]]
            if (valueList != []):
                rowList.extend(valueList[combo])
            rowList.append(fList[t])
            rowList.append(pList[t])
            rowList.append(vpList[t])
            rowList.append(cpList[t])
            rowList.extend(datasetLabels)
            dataValues.append(rowList)

# Put values in dataset
        spss.StartDataStep()
        datasetObj = spss.Dataset(name = datasetName)
        for t in dataValues:
            datasetObj.cases.append(t)
        spss.EndDataStep()

# Return to original data set
        spss.StartDataStep()
        datasetObj = spss.Dataset(name = activeName)
        spss.SetActive(datasetObj)
        spss.EndDataStep()

end program python.
set printback on.
COMMENT BOOKMARK;LINE_NUM=134;ID=1.
