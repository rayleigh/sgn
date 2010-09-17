/**
* @class Toolbar
* Functions used with the perl module of the same name
* @author Robert Buels <rmb32@cornell.edu>
*
*/

JSAN.use('jquery');

var CXGN;
if(!CXGN) CXGN = {};
if(!CXGN.Page) CXGN.Page = {};
if(!CXGN.Page.Toolbar)
  CXGN.Page.Toolbar = {
    timerID: null,
    timerOn: false,
    timecount: 400,
    menulist: new Array()
  };

CXGN.Page.Toolbar.showmenu = function(menu) {
  CXGN.Page.Toolbar.hideall();
  jQuery('> ul',menu).show();
  CXGN.Page.Toolbar.stopTime();
};

CXGN.Page.Toolbar.hidemenu = function() {
  CXGN.Page.Toolbar.startTime();
};

CXGN.Page.Toolbar.addmenu = function(menu) {
  CXGN.Page.Toolbar.menulist[CXGN.Page.Toolbar.menulist.length] = menu;
  jQuery(menu).hover(
     function() {
           CXGN.Page.Toolbar.showmenu(this);
     },
     function() {
           CXGN.Page.Toolbar.hideall();
     }
  );
};

CXGN.Page.Toolbar.startTime = function() { 
  if (CXGN.Page.Toolbar.timerOn == false) { 
    CXGN.Page.Toolbar.timerID = setTimeout( "CXGN.Page.Toolbar.hideall()" , CXGN.Page.Toolbar.timecount); 
    CXGN.Page.Toolbar.timerOn = true; 
  } 
}

CXGN.Page.Toolbar.stopTime = function() { 
  if (CXGN.Page.Toolbar.timerOn == true) { 
    clearTimeout(CXGN.Page.Toolbar.timerID); 
    CXGN.Page.Toolbar.timerID = null; 
    CXGN.Page.Toolbar.timerOn = false; 
  } 
};

CXGN.Page.Toolbar.hide = function(td) {
  jQuery('> ul',td).hide();
};

CXGN.Page.Toolbar.hideall = function() {
  for(var i=0; i<CXGN.Page.Toolbar.menulist.length; i++) {
    CXGN.Page.Toolbar.hide( CXGN.Page.Toolbar.menulist[i] );
  }
};

