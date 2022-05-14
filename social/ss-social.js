/*
* Symbolset
* www.symbolset.com
* Copyright © 2014 Oak Studios LLC
*
* Upload this file to your web server
* and place this before the closing </body> tag.
* <script src="webfonts/ss-social.js"></script>
*/

if (/(MSIE [7-9]\.|Opera.*Version\/(10\.[5-9]|(11|12)\.)|Chrome\/([1-9]|10)\.|Version\/[2-4][\.0-9]+ Safari\/|Version\/(4\.0\.[4-9]|4\.[1-9]|5\.0)[\.0-9]+? Mobile\/.*Safari\/|Android ([1-2]|4\.[2-9].*Version\/4)\.|BlackBerry.*WebKit)/.test(navigator.userAgent) && !/(IEMobile)/.test(navigator.userAgent)) {

  if (/Android 4\.[2-9].*Version\/4/.test(navigator.userAgent)) {
    var ss_android = document.createElement('style');
    ss_android.innerHTML = '.ss-icon,[class^="ss-"],[class*=" ss-"],[class^="ss-"]:before,[class*=" ss-"]:before,[class^="ss-"].right:after[class*=" ss-"].right:after{text-rendering:auto!important}';
    document.body.appendChild(ss_android);
  }

  var ss_set={'five hundred pixels':'\uF642','fivehundredpixels':'\uF642','five hundred px':'\uF642','github octocat':'\uF670','stack overflow':'\uF672','stack exchange':'\uF673','fivehundredpx':'\uF642','githuboctocat':'\uF670','stackoverflow':'\uF672','stackexchange':'\uF673','google plus':'\uF613','app dot net':'\uF614','kickstarter':'\uF681','google play':'\uF6FB','googleplus':'\uF613','letterboxd':'\uF632','foursquare':'\uF690','soundcloud':'\uF6B3','googleplay':'\uF6FB','blackberry':'\uF6F4','appdotnet':'\uF614','vkontakte':'\uF61A','wordpress':'\uF621','instagram':'\uF641','vsco grid':'\uF643','pinterest':'\uF650','delicious':'\uF655','bitbucket':'\uF674','app store':'\uF6FA','apple inc':'\uF8FF','microsoft':'\uF6F1','telephone':'\uD83D\uDCDE','thumbs up':'\uD83D\uDC4D','facebook':'\uF610','google +':'\uF613','about me':'\uF619','linkedin':'\uF612','vscogrid':'\uF643','pinboard':'\uF654','dribbble':'\uF660','jsfiddle':'\uF676','whatsapp':'\uF6A2','appstore':'\uF6FA','appleinc':'\uF8FF','envelope':'\u2709','thumbsup':'\uD83D\uDC4D','twitter':'\uF611','google+':'\uF613','app net':'\uF614','aboutme':'\uF619','blogger':'\uF622','youtube':'\uF630','dropbox':'\uF653','behance':'\uF661','octocat':'\uF670','codepen':'\uF675','shopify':'\uF683','spotify':'\uF6B1','last fm':'\uF6B2','windows':'\uF6F2','android':'\uF6F3','approve':'\uD83D\uDC4D','appnet':'\uF614','zerply':'\uF615','reddit':'\uF616','tumblr':'\uF620','flickr':'\uF640','feedly':'\uF656','github':'\uF670','paypal':'\uF680','lastfm':'\uF6B2','weibo':'\uF61B','steam':'\uF617','quora':'\uF624','vimeo':'\uF631','500px':'\uF642','swarm':'\uF692','skype':'\uF6A0','apple':'\uF8FF','phone':'\uD83D\uDCDE','email':'\u2709','share':'\uF601','ello':'\uF618','xing':'\uF61C','vine':'\uF633','etsy':'\uF682','yelp':'\uF691','rdio':'\uF6B0','link':'\uD83D\uDD17','call':'\uD83D\uDCDE','mail':'\u2709','like':'\uD83D\uDC4D','rss':'\uE310','vk':'\uF61A'};


  if (typeof ss_icons !== 'object' || typeof ss_icons !== 'object') {
    var ss_icons = ss_set;
    var ss_keywords = [];
    for (var i in ss_set) { ss_keywords.push(i); };
  } else {
    for (var i in ss_set) { ss_icons[i] = ss_set[i]; ss_keywords.push(i); }
  };

  if (typeof ss_legacy !== 'function') {

    /* domready.js */
    !function(a,b){typeof module!="undefined"?module.exports=b():typeof define=="function"&&typeof define.amd=="object"?define(b):this[a]=b()}("ss_ready",function(a){function m(a){l=1;while(a=b.shift())a()}var b=[],c,d=!1,e=document,f=e.documentElement,g=f.doScroll,h="DOMContentLoaded",i="addEventListener",j="onreadystatechange",k="readyState",l=/^loade|c/.test(e[k]);return e[i]&&e[i](h,c=function(){e.removeEventListener(h,c,d),m()},d),g&&e.attachEvent(j,c=function(){/^c/.test(e[k])&&(e.detachEvent(j,c),m())}),a=g?function(c){self!=top?l?c():b.push(c):function(){try{f.doScroll("left")}catch(b){return setTimeout(function(){a(c)},50)}c()}()}:function(a){l?a():b.push(a)}})

    var ss_legacy = function(node) {

      if (!node instanceof Object) return false;

      if (node.length) {
        for (var i=0; i<node.length; i++) {
          ss_legacy(node[i]);
        }
        return;
      };

      if (node.value) {
        node.value = ss_liga(node.value);
      } else if (node.nodeValue) {
        node.nodeValue = ss_liga(node.nodeValue);
      } else if (node.innerHTML) {
        node.innerHTML = ss_liga(node.innerHTML);
      }

    };

    var ss_getElementsByClassName = function(node, classname) {
      if (document.querySelectorAll) {
        return document.querySelectorAll('.'+classname);
      }
      var a = [];
      var re = new RegExp('(^| )'+classname+'( |$)');
      var els = node.getElementsByTagName("*");
      for(var i=0,j=els.length; i<j; i++)
          if(re.test(els[i].className))a.push(els[i]);
      return a;
    };

    var ss_liga = function(that) {
      var re = new RegExp(ss_keywords.join('|').replace(/[-[\]{}()*+?.,\\^$#\s]/g, "\\$&"),"gi");
      return that.replace(re, function(v) {
        return ss_icons[v.toLowerCase()];
      });
    };

    ss_ready(function() {
      if (document.getElementsByClassName) {
        ss_legacy(document.getElementsByClassName('ss-icon'));
      } else {
        ss_legacy(ss_getElementsByClassName(document.body, 'ss-icon'));
      }
    });

  }

};
