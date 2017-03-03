# freqDataset
Creates a dataset containing the frequencies of a set of variables. Rows in the dataset can be labeled, and the dataset can be appended by issuing the command multiple times, potentially with different labels each time.

## Usage
** freqDataset(varList, [datasetName], [datasetLabels])
* "var" is a list of strings indicating the names of the variables whose frequencies you want to calculate.
* "datasetName" is the name of the SPSS dataset you want to hold the frequencies. By default, the name of the dataset is "Frequencies".
* "datasetLabels" is an optional argument that identifies a list of strings identifying values that would be applied to the dataset.  This can be useful if you are appending the results from multiple analyses to the same dataset.

## Example
** freqDataset(varList = ["race", "gender", "grade"],
** datasetName = "Demographics",
** datasetLabels = ["Fall", "2016"])
* This would calculate the frequencies for race, gender, and grade, and then put the results in a dataset named "Demographics". 
* There would be variables in the Demographics data set for the variable, the value, the frequency corresponding to the value, and two labels. 
* For all of the cases added by this command, the value of the first label would be "Fall" and the value of the second label would be "2016".
