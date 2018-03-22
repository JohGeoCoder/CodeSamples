//This computed function retrieves and properly maps the Prod
//Avail time records into Categories based on the selected 
//Prod Avail Information.
self.TimeCategories = ko.pureComputed(function(){                        
	var selectedTimeCategoryInfo = self.SelectedTimeCategoryInfo();
	
	var timeCategoryMap = {};
	
	if(!selectedTimeCategoryInfo){
		return timeCategoryMap;
	}
	
	//Map the raw time records into categories for display.
	if(selectedTimeCategoryInfo.hasOwnProperty('TimeCategories')){
		selectedTimeCategoryInfo.TimeCategories().map(function(timeCategory){
			if(!timeCategory.Category || !timeCategory.PerfTime || !timeCategory.PerfType){
				return;
			}

			if(!this.hasOwnProperty(timeCategory.Category)){
				this[timeCategory.Category] = [];
			}

			this[timeCategory.Category].push({
				'PerfType': timeCategory.PerfType,
				'PerfTime': timeCategory.PerfTime
			});
		}, timeCategoryMap);
	}
				
	return timeCategoryMap;
});