// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults 

//things to do when the page loads
document.observe("dom:loaded", function () {
	hideFormFields(); 
	hideFilters();
	initSelect('languages_menu');
});


// Toggles the chaptered story section of the work form and resets the wip_length field
function showChapteredStoryOptions() {
	var item = document.getElementById('work_wip_length');
	if (item.value == 1) {item.value = '?';}
	else {item.value = 1;}
	Element.toggle('number-of-chapters');
}

// Toggles the backdating options section of the work form
function showBackdateOptions() {
	Element.toggle('publicationdateoptions');
}

// Toggles the chaptered story section of the work form and resets the wip_length field
function showWorkSeriesOptions() {
	var checkbox = document.getElementById('storyseriescheck');
	var seriesField = document.getElementById('work_series_attributes_title');
	var seriesSelect = document.getElementById('work_series_attributes_id');
	if (!checkbox.checked) {
		seriesField.value = '';
		seriesSelect.selectedIndex = 0;
	}
	Element.toggle('seriesmanage');
}

function showOptions(idToCheck, idToShow) {
    var checkbox = document.getElementById(idToCheck);
    var areaToShow = document.getElementById(idToShow);
    if (checkbox.checked) {
        Element.toggle(idToShow)
    }
}

function selectAllCheckboxes(basefield, count, checked) {
    var checkbox;
    for (i=1; i<=count; i++) {
        checkbox = document.getElementById(basefield + '_' + i);
        if (checked == 'invert') {
            checkbox.checked = !checkbox.checked
        } else {
            checkbox.checked = checked
        }
    }
}

// Hides expandable form field options if Javascript is enabled
function hideFormFields() {
	var coAuthors = document.getElementById('co-authors');
	if (coAuthors != null) coAuthors.style.display='none';
	 
	if (document.storyForm != null) var isWip = document.storyForm.isWip;
	var chapteredOptions = document.getElementById('number-of-chapters');
	if (isWip != null && chapteredOptions != null && !isWip.checked) chapteredOptions.style.display='none';
	
	if (document.storyForm != null) var hasSeries = document.storyForm.storyseriescheck;
	var seriesOptions = document.getElementById('seriesmanage');
	if (hasSeries != null && seriesOptions != null && !hasSeries.checked) seriesOptions.style.display='none';
	
	if (document.storyForm != null) var isBackdated = document.storyForm.publicationdatecheck;
	var backdateOptions = document.getElementById('publicationdateoptions');
	if (isBackdated != null && backdateOptions != null && !isBackdated.checked) backdateOptions.style.display='none';	
}

// Toggles items in filter list
function toggleFilters(id, blind_duration) {
    
	blind_duration = (blind_duration == null ? 0.2 : blind_duration = 0.2)
    var filter = document.getElementById(id);
	var filter_open = document.getElementById(id + "_open")
	var filter_closed = document.getElementById(id + "_closed")
	if (filter != null) {
		Effect.toggle(filter, 'blind', {duration: blind_duration});
		Effect.toggle(filter_open, 'appear', {duration: 0})
		Effect.toggle(filter_closed, 'appear', {duration: 0})
	}
}

// Collapses filter list if Javascript is enabled
function hideFilters() {
	var filters = $$('dd.tags');
	filters.each(function(filter) {
		var tags = filter.select('input');
		var selected = false;
		tags.each(function(tag) {if (tag.checked) selected=true});
		if (selected != true) {toggleFilters(filter.id, 0);}
	});	
}

// Toggles login block
function toggleLogin(id, blind_duration) {
	blind_duration = (blind_duration == null ? 0.2 : blind_duration)
    var signin = document.getElementById(id);
	var signin_open = document.getElementById(id + "_open")
	var signin_closed = document.getElementById(id + "_closed")
	if (signin != null) {
		Effect.toggle(signin, 'blind', {duration: blind_duration});
		Effect.toggle(signin_open, 'appear', {duration: 0.0})
		Effect.toggle(signin_closed, 'appear', {duration: 0.0})
	}
}

// Rolls up Login if Javascript is enabled
function hideLogin() {
	var signin = $$('#signin');
	signin.each(function(signin) {
		var tags = signin.select('input');
		var selected = false;
		tags.each(function(tag) {if (tag.checked) selected=true});
		if (selected != true) {toggleLogin(signin.id, 0.0);}
	});	
}