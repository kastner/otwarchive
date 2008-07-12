//Init script for calling tinyMCE rich text editor: basic configuration can be done here.

tinyMCE.init({
	theme:"advanced",
	mode:"none",
	editor_selector:"mce-editor",

	
	// Theme options - using the advanced theme for now and just limiting the buttons used - we may want to create a custom theme in future.
	theme_advanced_buttons1 : "bold,italic,underline,strikethrough,fontselect,fontsizeselect,|,link,unlink,image,|,outdent,indent,blockquote,|,bullist,numlist,|,justifyleft,justifycenter,justifyright,justifyfull,|,undo,redo",
	theme_advanced_buttons2 : "",
	theme_advanced_buttons3 : "",
	theme_advanced_toolbar_location : "top",
	theme_advanced_toolbar_align : "left",
	theme_advanced_resizing : true,

});

//Allows the user to turn the rich text editor off and on. 

function addEditor(id) {
			tinyMCE.execCommand('mceAddControl', false, id)
					
}

function removeEditor(id) {
		tinyMCE.execCommand('mceRemoveControl', false,  id)
}






