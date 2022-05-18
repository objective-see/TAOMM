
/* new page/tab, etc */
if(document.referrer.indexOf("taomm.org") == -1) {

    $(document).ajaxStart(function() {
        $("#loader").show();
        $("#loader").css('visibility','visible');
    });

    $(document).ajaxStop(function() {
        $("#loader").delay(700).fadeOut(100)
        $("#loading").delay(700).fadeOut(500)
        $("#content").show();
    });
}

else
{
    $(document).ajaxStop(function() {
        $("#loading").hide();
        $("#content").show();
    });

}

    







