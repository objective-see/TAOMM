if(document.referrer.indexOf("taomm.org") == -1) {

	$(document).ajaxStart(function() {
        $("#loading").show();
    });

    $(document).ajaxStop(function() {
        $("#loader").delay(700).fadeOut(100)
        $("#loading").delay(700).fadeOut(500)
    });
}
  
