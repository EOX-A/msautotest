/* ===========================================================================
   $Id$
 
   Project:  MapServer
   Purpose:  SWIG interface file for mapscript layerObj extensions
   Author:   Steve Lime 
             Sean Gillies, sgillies@frii.com
             
   ===========================================================================
   Copyright (c) 1996-2001 Regents of the University of Minnesota.
   
   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the "Software"),
   to deal in the Software without restriction, including without limitation
   the rights to use, copy, modify, merge, publish, distribute, sublicense,
   and/or sell copies of the Software, and to permit persons to whom the
   Software is furnished to do so, subject to the following conditions:
 
   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.
 
   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
   THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.
   ===========================================================================
*/

%extend layerObj 
{

    layerObj(mapObj *map=NULL) 
    {
        layerObj *layer;
        int result;
        
        if (!map) {
            layer = (layerObj *) malloc(sizeof(layerObj));
            if (!layer) {
                msSetError(MS_MEMERR, "Failed to initialize Layer",
                                       "layerObj()");
                return NULL;
            } 
            result = initLayer(layer, NULL);
            if (result == MS_SUCCESS) {
                layer->index = -1;
                return layer;
            }
            else {
                msSetError(MS_MEMERR, "Failed to initialize Layer",
                                       "layerObj()");
                return NULL;
            }
        }
        else {
            if (map->numlayers == MS_MAXLAYERS) {
                msSetError(MS_CHILDERR, "Max number of layers exceeded",
                                        "layerObj()");
                return(NULL);
            }

            if (initLayer(&(map->layers[map->numlayers]), map) == -1)
                return(NULL);

            map->layers[map->numlayers].index = map->numlayers;
            map->layerorder[map->numlayers] = map->numlayers;
            map->numlayers++;

            return &(map->layers[map->numlayers-1]);
        }
    }

    ~layerObj() 
    {
        if (!self->map) {
            freeLayer(self);
            free(self);
        }
    }

#ifdef SWIGJAVA
    %newobject cloneLayer;
    layerObj *cloneLayer() 
#else
    %newobject clone;
    layerObj *clone() 
#endif
    {
        layerObj *layer;
        int result;

        layer = (layerObj *) malloc(sizeof(layerObj));
        if (!layer) {
            msSetError(MS_MEMERR, "Failed to initialize Layer",
                                  "layerObj()");
            return NULL;
        } 
        result = initLayer(layer, NULL);
        if (result != MS_SUCCESS) {
            msSetError(MS_MEMERR, "Failed to initialize Layer",
                                  "layerObj()");
            return NULL;
        }

        if (msCopyLayer(layer, self) != MS_SUCCESS) {
            freeLayer(layer);
            free(layer);
            layer = NULL;
        }
        layer->map = NULL;
        layer->index = -1;
        
        return layer;
    }

    int insertClass(classObj *classobj, int index=-1)
    {
        return msInsertClass(self, classobj, index);
    }
    
    /* removeClass() */
    %newobject removeClass;
    classObj *removeClass(int index) 
    {
        return msRemoveClass(self, index);
    }

    int open() 
    {
        int status;
        status =  msLayerOpen(self);
        if (status == MS_SUCCESS) {
            return msLayerGetItems(self);
        }
        return status;
    }

    int whichShapes(rectObj rect)
    {
        /* 
        ** We assume folks use this like a simple query so retrieve all items with each shape.
        */
        msLayerGetItems(self);
        return msLayerWhichShapes(self, rect);
    }	

    %newobject nextShape;
    shapeObj *nextShape() 
    {
       int status;
       shapeObj *shape;

       shape = (shapeObj *)malloc(sizeof(shapeObj));
       if (!shape) return NULL;
       msInitShape(shape);

       status = msLayerNextShape(self, shape);
       if(status != MS_SUCCESS) {
         msFreeShape(shape);
	 free(shape);
	 return NULL;
       } else
         return shape;
    }

    void close() 
    {
        msLayerClose(self);
    }

    %newobject getFeature;
    shapeObj *getFeature(int shapeindex, int tileindex=-1) 
    {
    /* This version properly returns shapeObj and also has its
     * arguments properly ordered so that users can ignore the
     * tileindex if they are not accessing a tileindexed layer.
     * See bug 586:
     * http://mapserver.gis.umn.edu/bugs/show_bug.cgi?id=586 */
        int retval;
        shapeObj *shape;
        shape = (shapeObj *)malloc(sizeof(shapeObj));
        if (!shape)
            return NULL;
        msInitShape(shape);
        shape->type = self->type;
        retval = msLayerGetShape(self, shape, tileindex, shapeindex);
        return shape;
    }

    int getShape(shapeObj *shape, int tileindex, int shapeindex) 
    {
        return msLayerGetShape(self, shape, tileindex, shapeindex);
    }
  
    int getNumResults() 
    {
        if (!self->resultcache) return 0;
        return self->resultcache->numresults;
    }

    resultCacheMemberObj *getResult(int i) 
    {
        if (!self->resultcache) return NULL;
        if (i >= 0 && i < self->resultcache->numresults)
            return &self->resultcache->results[i]; 
        else
            return NULL;
    }

    classObj *getClass(int i) 
    {

        if (i >= 0 && i < self->numclasses)
            return &(self->class[i]); 
        else
            return NULL;
    }

    char *getItem(int i) 
    {
  
        if (i >= 0 && i < self->numitems)
            return (char *) (self->items[i]);
        else
            return NULL;
    }

    int draw(mapObj *map, imageObj *image) 
    {
        return msDrawLayer(map, self, image);    
    }

    int drawQuery(mapObj *map, imageObj *image) 
    {
        return msDrawQueryLayer(map, self, image);    
    }

    /* For querying, we switch layer status ON and then back to original
       value before returning. */

    int queryByAttributes(mapObj *map, char *qitem, char *qstring, int mode) 
    {
        int status;
        int retval;
        
        status = self->status;
        self->status = MS_ON;
        retval = msQueryByAttributes(map, self->index, qitem, qstring, mode);
        self->status = status;
        return retval;
    }

    int queryByPoint(mapObj *map, pointObj *point, int mode, double buffer) 
    {
        int status;
        int retval;
        
        status = self->status;
        self->status = MS_ON;
        retval = msQueryByPoint(map, self->index, mode, *point, buffer);
        self->status = status;
        return retval;
    }

    int queryByRect(mapObj *map, rectObj rect) 
    {
        int status;
        int retval;
        
        status = self->status;
        self->status = MS_ON;
        retval = msQueryByRect(map, self->index, rect);
        self->status = status;
        return retval;
    }

    int queryByFeatures(mapObj *map, int slayer) 
    {
        int status;
        int retval;
        
        status = self->status;
        self->status = MS_ON;
        retval = msQueryByFeatures(map, self->index, slayer);
        self->status = status;
        return retval;
    }

    int queryByShape(mapObj *map, shapeObj *shape) 
    {
        int status;
        int retval;
        
        status = self->status;
        self->status = MS_ON;
        retval = msQueryByShape(map, self->index, shape);
        self->status = status;
        return retval;
    }

    int queryByIndex(mapObj *map, int tileindex, int shapeindex,
                     int bAddToQuery=MS_FALSE)
    {
        int status;
        int retval;
        
        status = self->status;
        self->status = MS_ON;
        if (bAddToQuery == MS_FALSE)
            retval = msQueryByIndex(map, self->index, tileindex, shapeindex);
        else
            retval = msQueryByIndexAdd(map, self->index, tileindex, shapeindex);
        self->status = status;
        return retval;
    }
    
    resultCacheObj *getResults(void)
    {
        return self->resultcache;
    }
        
    int setFilter(char *filter) 
    {
        if (!filter || strlen(filter) == 0) {
            freeExpression(&self->filter);
            return MS_SUCCESS;
        }
        else return msLoadExpressionString(&self->filter, filter);
    }

    %newobject getFilterString;
    char *getFilterString() 
    {
        return msGetExpressionString(&(self->filter));
    }

    int setWKTProjection(char *wkt) 
    {
        self->project = MS_TRUE;
        return msOGCWKT2ProjectionObj(wkt, &(self->projection), self->debug);
    }

    %newobject getProjection;
    char *getProjection() 
    {    
        return (char *) msGetProjectionString(&(self->projection));
    }

    int setProjection(char *proj4) 
    {
        self->project = MS_TRUE;
        return msLoadProjectionString(&(self->projection), proj4);
    }

    int addFeature(shapeObj *shape) 
    {    
        self->connectiontype = MS_INLINE;
        if (insertFeatureList(&(self->features), shape) == NULL) 
        return MS_FAILURE;
        return MS_SUCCESS;
    }

    /*
    Returns the number of inline feature of a layer
    */
    int getNumFeatures() 
    {
        return msLayerGetNumFeatures(self);
    }

    %newobject getExtent;
    rectObj *getExtent() 
    {
        rectObj *extent;
        extent = (rectObj *) malloc(sizeof(rectObj));
        msLayerGetExtent(self, extent);
        return extent;
    }

    int setExtent(double minx=-1.0, double miny=-1.0,
                  double maxx=-1.0, double maxy=-1.0)
    {
        if (minx > maxx || miny > maxy) {
            msSetError(MS_RECTERR,
                "{ 'minx': %f , 'miny': %f , 'maxx': %f , 'maxy': %f }",
                "layerObj::setExtent()", minx, miny, maxx, maxy);
            return MS_FAILURE;
        }

        return msLayerSetExtent(self, minx, miny, maxx, maxy);
    }
    
    /* 
    The following metadata methods are no longer needed since we have
    promoted the metadata member of layerObj to a first-class mapscript
    object.  See hashtable.i.  Not yet scheduled for deprecation but 
    perhaps in the next major release?  --SG
    */ 
    char *getMetaData(char *name) 
    {
        char *value = NULL;
        if (!name) {
            msSetError(MS_HASHERR, "NULL key", "getMetaData");
        }
     
        value = (char *) msLookupHashTable(&(self->metadata), name);
	/*
	Umberto, 05/17/2006
	Exceptions should be reserved for situations when a serious error occurred
	and normal program flow must be interrupted.
	In this case returning null should be more that enough.
	*/
#ifndef SWIGJAVA
        if (!value) {
            msSetError(MS_HASHERR, "Key %s does not exist", "getMetaData", name);
            return NULL;
        }
#endif
        return value;
    }

    int setMetaData(char *name, char *value) 
    {
        if (msInsertHashTable(&(self->metadata), name, value) == NULL)
        return MS_FAILURE;
        return MS_SUCCESS;
    }

    int removeMetaData(char *name) 
    {
        return(msRemoveHashTable(&(self->metadata), name));
    }

    char *getFirstMetaDataKey() 
    {
        return (char *) msFirstKeyFromHashTable(&(self->metadata));
    }
 
    char *getNextMetaDataKey(char *lastkey) 
    {
        return (char *) msNextKeyFromHashTable(&(self->metadata), lastkey);
    }
  
    %newobject getWMSFeatureInfoURL;
    char *getWMSFeatureInfoURL(mapObj *map, int click_x, int click_y,
                               int feature_count, char *info_format)
    {
        return (char *) msWMSGetFeatureInfoURL(map, self, click_x, click_y,
               feature_count, info_format);
    }
 
    %newobject executeWFSGetFeature;
    char *executeWFSGetFeature(layerObj *layer) 
    {
        return (char *) msWFSExecuteGetFeature(layer);
    }

    int applySLD(char *sld, char *stylelayer) 
    {
        return msSLDApplySLD(self->map, sld, self->index, stylelayer);
    }

    int applySLDURL(char *sld, char *stylelayer) 
    {
        return msSLDApplySLDURL(self->map, sld, self->index, stylelayer);
    }

    %newobject generateSLD; 
    char *generateSLD() 
    {
        return (char *) msSLDGenerateSLD(self->map, self->index);
    }

    int isVisible()
    {
        if (!self->map)
        {
            msSetError(MS_MISCERR,
                "visibility has no meaning outside of a map context",
                "isVisible()");
            return MS_FAILURE;
        }
        return msLayerIsVisible(self->map, self);
    }

    int moveClassUp(int index) 
    {
        return msMoveClassUp(self, index);
    }

    int moveClassDown(int index) 
    {
        return msMoveClassDown(self, index);
    }

    void setProcessingKey(const char *key, const char *value) 
    {
	   msLayerSetProcessingKey( self, key, value );
    }
 
    /* this method is deprecated ... should use addProcessing() */
    void setProcessing(const char *directive ) 
    {
        msLayerAddProcessing( self, directive );
    }

    void addProcessing(const char *directive ) 
    {
        msLayerAddProcessing( self, directive );
    }

    char *getProcessing(int index) 
    {
        return (char *) msLayerGetProcessing(self, index);
    }

    int clearProcessing() 
    {
        return msLayerClearProcessing(self);
    }

}