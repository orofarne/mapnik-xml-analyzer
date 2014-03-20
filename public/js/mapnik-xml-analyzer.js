function loadURows(layer) {
	var obj_name = '#' + layer + '-urows-data';
	var obj = $(obj_name);

	if (obj.text() != 'loading...') {
		return;
	}

	$.get("/urows/" + layer)
		.done(function( data ) {
			obj.text(data);
			obj.each(function(i, e) {hljs.highlightBlock(e)});
		});
}

function initEditor(layer) {
	$.get('/getsql/' + layer)
		.done(function(data) {
			var editor_e = $('#editor');
			editor_e.text(data);
			var editor = ace.edit("editor");
			editor.setTheme("ace/theme/github");
			editor.getSession().setMode("ace/mode/pgsql");
			editor_e.data('editor', editor);
		})
		.fail(function() {
			alert('error');
		});
}

function checkSQL(layer) {
	var sql = $('#editor').data('editor').getSession().getValue();
	var sqlmsg = $('#sqlmsg');

	sqlmsg.text('processing...');
	sqlmsg.attr('class', 'label');

	$.post('/checksql/' + layer, sql)
		.done(function(data) {
			sqlmsg.text(data);
			if (data == 'Ok') {
				sqlmsg.attr('class', 'label label-success');
			} else if (data.startsWith('SQL ERROR') || data.startsWith('WARNING')) {
				sqlmsg.attr('class', 'label label-important');
			} else {
				sqlmsg.attr('class', 'label label-warning')
			}
		})
		.fail(function() {
			alert('error');
		});
}

function doneSQL(layer) {
	var sql = $('#editor').data('editor').getSession().getValue();
	var sqlmsg = $('#sqlmsg');

	sqlmsg.text('processing...');
	sqlmsg.attr('class', 'label label-info');

	$.post('/sqleditdone/' + layer, sql)
		.done(function(data) {
			$('#page').html(data);
		})
		.fail(function() {
			alert('error');
		});
}
