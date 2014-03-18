function loadURows(layer) {
	var obj_name = '#' + layer + '-urows-data';
	var obj = $(obj_name);

	if (obj.text() != 'loading...') {
		return;
	}

	$.ajax("/urows/" + layer)
		.done(function( data ) {
			obj.text(data);
			obj.each(function(i, e) {hljs.highlightBlock(e)});
		});
}
