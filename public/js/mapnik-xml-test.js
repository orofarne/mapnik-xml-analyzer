function loadURows(layer) {
	var obj_name = '#' + layer + '-urows-data';

	if ($(obj_name).text() != 'loading...') {
		return;
	}

	$.ajax("/urows/" + layer)
		.done(function( data ) {
			$(obj_name).text(data);
		});
}
