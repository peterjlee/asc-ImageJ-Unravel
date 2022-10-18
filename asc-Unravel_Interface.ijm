/* This macro unravels an outline (aimed at curved surfaces) so that x coordinates are relative to adjacent pixels and y coordinates are relative to a single point (or line - not activated yet).
	It is assumed that a pixel-width outline has already been created.
	Inspired by an idea proposed by Jeremy Adler <jeremy.adler@IGP.UU.SE> from an imageJ mailing list post on Monday, August 15, 2022 4:17 AM
	v220825 1st version.
	v221003 Adds option to create pseudo-height map for analysis in 3D analysis software like Gwyddion. Also report for sampling length based in shape
	v221004 Replaces "None" with "Total_pixel-pixel_length" in sample length options
	v221005 Default median smoothing radius determined from initial bounding box. Aspected pixel fix. Smoothed image can be generated independent of ref length.
*/
	macroL = "Unravel_interface_v221005.ijm";
	oTitle = getTitle;
	oID = getImageID();
	if (!is("binary")){
		if(getBoolean("This macro expects a binary image, would you like to try a apply a quick fix?")) toWhiteBGBinary(oTitle);
		else ("Goodbye");
	}
	oImageW = Image.width;
	oImageH = Image.height;
	run("Create Selection");
	getSelectionBounds(minX, minY, widthS, heightS);
	if(minX + widthS==oImageW || minY + heightS==oImageH){
		if(getBoolean("This macro expects an object that is not touching the edge; would you like to expand the canvas?")) run("Canvas Size...", "width=" + (oImageW+2) + " height=" + (oImageH+2) + " position=Center");
		else exit("Goodbye");
	}
	defMedR = round((widthS + heightS)/(10*PI));
	bBoxX = minX + widthS/2;
	bBoxY = minY + heightS/2;
	run("Select None");
	nTitle = stripKnownExtensionFromString(oTitle);
	getPixelSize(unit, pixelWidth, pixelHeight);
	lcf=(pixelWidth+pixelHeight)/2; /* ---> add here the side size of 1 pixel in the new calibrated units (e.g. lcf=5, if 1 pixels is 5mm) <--- */
	getDimensions(oWidth, oHeight, oChannels, oSlices, oFrames);
	objectTypes = newArray("Continuous_Outline","Solid_object","Something_else");
	refLengths = newArray("Total_pixel-pixel_length","Circle_perimeter","Ellipse_perimeter","Object_Perimeter","Median_smoothed_object_perimeter");
	Dialog.create("Unraveling options 1: \(" + macroL + "\)");
		Dialog.addMessage("This macro currently only works on a single solid object or continuous outline",11,"red");
		if(oChannels+oSlices+oFrames!=3) Dialog.addMessage("Warning: This macro has only been tested on single slice-frame-channel images",12,"red");
		Dialog.addRadioButtonGroup("Object type:",objectTypes,objectTypes.length,1,objectTypes[1]);
		Dialog.addRadioButtonGroup("Output sampling length:",refLengths,refLengths.length,1,refLengths[2]);
		Dialog.addCheckbox("Create pseudo-height map from interface",true);
		Dialog.addCheckbox("Create median smoothed object \(i.e. physical waviness\)",true);
		Dialog.addNumber("Median radius for smoothed surface length",defMedR,0,4,"pixels");
		Dialog.addCheckbox("Diagnostics",false);
	Dialog.show;
		objectType = Dialog.getRadioButton();
		refLength = Dialog.getRadioButton();
		hMap = Dialog.getCheckbox();
		smoothKeep = Dialog.getCheckbox();
		smoothN = Dialog.getNumber();
		diagnostics = Dialog.getCheckbox();
	if (objectType=="Something_else") exit("Sorry, I am not ready for 'something else' yet");
	if(!diagnostics) setBatchMode(true);
	run("Duplicate...", "title=unRavel_temp");
	run("Convert to Mask");
	if (is("Inverting LUT")) run("Invert LUT");
	medianBGIs = guessBGMedianIntensity();
	medianBGI = round((medianBGIs[0]+medianBGIs[1]+medianBGIs[2])/3);
	if (medianBGI==0) run("Invert");
	run("Select None");
	dID = getImageID();
	if(refLength!="Total_pixel-pixel_length"){
		run("Select None");
		run("Duplicate...", "title=refLength_temp");
		run("Fill Holes");  /* allows rest to work with outline or solid object */
		if(refLength=="Ellipse_perimeter" || refLength=="Circle_perimeter"){
			run("Create Selection");
			if(refLength=="Ellipse_perimeter")	run("Fit Ellipse");
			else {
				run("Fit Circle");
				getSelectionBounds(null, null, diameter, null);
				lRef = lcf * 2 * PI * diameter/2;
			}
		}
		else if(startsWith(refLength,"Median")){
			run("Median...", "radius=&smoothN");
			medianT = nTitle + "_median" + smoothN;
			rename(medianT);
			run("Create Selection");
		}
		else run("Create Selection");
		getSelectionBounds(fMinX, fMinY, fWidthS, fHeightS);
		fBoxX = fMinX + fWidthS/2;
		fBoxY = fMinY + fHeightS/2;
		if(refLength!="Circle_perimeter"){
			run("Clear", "slice");
			run("Invert");
			run("Clear Outside");
			List.setMeasurements;
			// print(List.getList); // list all measurements
			lRef = List.getValue("Perim.");
		}
		run("Select None");
		if (!diagnostics) closeImageByTitle("refLength_temp");
	}
	selectImage(dID);
	if(!startsWith(refLength,"Median") && smoothKeep){
		/* A smoothed image may be wanted for determination of physical waviness, while the reference length could be something else */ 
		run("Select None");
		medianT = nTitle + "_median" + smoothN;
		run("Duplicate...", "title="+medianT);
		run("Median...", "radius=&smoothN");
	}
	selectImage(dID);
	if (objectType!="Outline") run("Outline");
	run("Skeletonize");
	// run("Select None");
	// call("Versatile_Wand_Tool.doWand", 0, 0, 0.0, 0.0, 0.0, "8-connected");
	// run("Make Inverse");
	run("Create Selection");
	getSelectionBounds(minBX, minBY, widthB, heightB);
	maxBX = minBX + widthB;
	maxBY = minBY + heightB;
	mostPixels = widthB*heightB;
	run("Select None");
	xSeqCoords = newArray();
	ySeqCoords = newArray();
	for(topY=minBY,done=false;topY<maxBY+1 && !done; topY++){
		for(topX=minBX;topX<maxBX+1 && !done; topX++) if (getPixel(topX,topY)!=255)	done = true;
	}
	for(leftX=minBX,done=false;leftX<maxBX+1 && !done; leftX++){
		for(leftY=minBY;leftY<maxBY+1 && !done; leftY++) if (getPixel(leftX,leftY)!=255)	done = true;
	}
	startCoordOptions = newArray("Top pixel \("+topX+","+topY+"\)","Left  pixel \("+leftX+","+leftY+"\)","Manual entry");
	Dialog.create("Unraveling options 2: \(" + macroL + "\)");
		Dialog.addRadioButtonGroup("Starting point:",startCoordOptions,startCoordOptions.length,1,startCoordOptions[1]);
		Dialog.addNumber("Manual start x",0,0,3,"pixels");
		Dialog.addNumber("Manual start y",0,0,3,"pixels");
		Dialog.addNumber("Pixel search range in plus and minus pixels",6,0,3,"pixels");
		Dialog.addCheckbox("Is outline continuous \(i.e. a circle\)?",true);
		Dialog.addCheckbox("Try to start clockwise",true);
		Dialog.addCheckbox("Create map to show pixel sequence",true);
		Dialog.addCheckbox("Output rotational sequence values",false);
	Dialog.show;
		startCoordOption = Dialog.getRadioButton();
		x = Dialog.getNumber();
		y = Dialog.getNumber();
		kernelR = Dialog.getNumber();
		continuous = Dialog.getCheckbox();
		clockwise = Dialog.getCheckbox();
		showPixelSequence = Dialog.getCheckbox();
		angleOut = Dialog.getCheckbox();
	setBatchMode(true);
	if (startsWith(startCoordOption,"Top")){
		x = topX;
		y = topY;
	}
	else if (startsWith(startCoordOption,"Left")){
		x = leftX;
		y = leftY;
	}
	xSearchPxlsA = newArray();
	ySearchPxlsA = newArray();
	dSearchPxls  =newArray();
	for(i=(0-kernelR),k=0; i<kernelR+1; i++){
		for (j=(0-kernelR); j<kernelR+1; j++){
			xSearchPxlsA[k] = j;
			ySearchPxlsA[k] = i;
			dSearchPxls[k] = i*i + j*j;
			k++;
		}
	}
	xSearchPxls = newArray();
	ySearchPxls = newArray();
	dSearchPxlsRank = Array.rankPositions(dSearchPxls);
	for(i=1;i<dSearchPxlsRank.length;i++){
		r = dSearchPxlsRank[i];
		xSearchPxls[i-1] = xSearchPxlsA[r];
		ySearchPxls[i-1] = ySearchPxlsA[r];
	}
	if(clockwise){
		xSearchPxls = Array.concat(1,1,1,0,0,xSearchPxls);
		ySearchPxls = Array.concat(-1,0,1,-1,1,ySearchPxls);
	}
	if (diagnostics) Array.print(xSearchPxls);
	if (diagnostics) Array.print(ySearchPxls);
	done = false;
	xSeqCoords[0] = x;
	ySeqCoords[0] = y;
	setPixel(x,y,255);
	nSearchPxls = xSearchPxls.length;
	for(i=1,k=0; i<mostPixels-1 && !done; i++){
		for(j=0,gotPix=false; j<nSearchPxls+1 && !gotPix; j++){
			if(j==nSearchPxls) done = true;
			else{
				testX = xSeqCoords[k] + xSearchPxls[j];
				testY = ySeqCoords[k] + ySearchPxls[j];
				testI = getPixel(testX,testY);
				if (testI==0){
					k++;
					xSeqCoords[k] = testX;
					ySeqCoords[k] = testY;
					setPixel(xSeqCoords[k],ySeqCoords[k],255);
					if (diagnostics) print(k,xSeqCoords[k],ySeqCoords[k]);
					gotPix = true;
				}
			}
		}
	}
	Array.getStatistics(xSeqCoords, xSeqCoords_min, xSeqCoords_max, xSeqCoords_mean, xSeqCoords_stdDev);
	Array.getStatistics(ySeqCoords, ySeqCoords_min, ySeqCoords_max, ySeqCoords_mean, ySeqCoords_stdDev);
	seqPixN = xSeqCoords.length;
	if (diagnostics) print(seqPixN + "coordinates in sequence");
	xDistances = newArray();
	xDistances[0] = 0;
	for (i=1;i<seqPixN;i++){
		relI = i-1;
		if(relI<1){
			if(continuous) iD = seqPixN+relI-1;
			else iD = 0;
		}
		else iD = i-1;
		xDistances[i] = pow((pow(xSeqCoords[i]-xSeqCoords[iD],2) + pow(ySeqCoords[i]-ySeqCoords[iD],2)),0.5);
	}
	if(continuous && angleOut){
		radianAngles = newArray();
		radianOffsets = newArray();
		degreeOffsets = newArray();
		for (i=0;i<seqPixN;i++) radianAngles[i] = atan2(xSeqCoords[i],ySeqCoords[i]);
		for (i=0;i<seqPixN;i++) radianOffsets[i] = radianAngles[i] - radianAngles[0];
		for (i=0;i<seqPixN;i++) degreeOffsets[i] = radianOffsets[i] * 180/PI;
	}
	xDistancesTotal = newArray();
	xDistancesTotal[0] = 0;
	if(lcf!=1){
		xSDistancesTotal = newArray();
		xSDistancesTotal[0] = 0;
	}
	for (i=1;i<seqPixN;i++) xDistancesTotal[i] = xDistancesTotal[i-1] + xDistances[i];
	if(lcf!=1) for (i=1;i<seqPixN;i++) xSDistancesTotal[i] = lcf * xDistancesTotal[i];
	Array.getStatistics(xDistancesTotal, xDistancesTotal_min, xDistancesTotal_max, xDistancesTotal_mean, xDistancesTotal_stdDev);
	if(refLength=="Total_pixel-pixel_length") lRef = xDistancesTotal_max;
	lName = replace(refLength,"_"," ");
	if(startsWith(refLength,"Median")) {
		lName = replace(lName,"Median smoothed","Median \("+smoothN+" pixel radius\) smoothed");
		if (!smoothKeep) closeImageByTitle(medianT);
	}	
	IJ.log("For " + oTitle + ":\n" + lName + " = " + lRef + " " + unit);
	if(continuous){
		refLocs = newArray("Sequential_pixel_centroid","Bounding_box_center","Image_center");
		dimensionsText = "Sequential pixel centroid: x = " + xSeqCoords_mean + ", y = " + ySeqCoords_mean + "\nBounding box center: x = " + bBoxX + ", y = " + bBoxY+ "\nImage center: x = " + oImageW/2 + ", y = " + oImageH/2;
		Dialog.create("Height reference coordinate \(" + macroL + "\)");
			if(refLength!="Total_pixel-pixel_length"){
				refLocs = Array.concat(refLocs,"Reference_shape_center");
				refShapeName = replace(lName,"perimeter","");
				dimensionsText += "\nReference shape \(" + refShapeName + "\) center: x = " + fBoxX + ", y = " + fBoxY;
			}
			refLocs = Array.concat(refLocs,"Arbitrary_coordinates");
			Dialog.addMessage(dimensionsText);
			Dialog.addRadioButtonGroup("Reference location for height:",refLocs,refLocs.length,1,refLocs[0]);
			Dialog.addNumber("Arbitrary x", 0,0,10,"pixels");
			Dialog.addNumber("Arbitrary y", 0,0,10,"pixels");
		Dialog.show;
			refLoc = Dialog.getRadioButton();
			xRef = Dialog.getNumber();
			yRef = Dialog.getNumber();
		if (startsWith(refLoc,"Sequential")){
			xRef = xSeqCoords_mean;
			yRef = ySeqCoords_mean;	
		}
		else if (startsWith(refLoc,"Image")){
			xRef = oImageW/2;
			yRef = oImageH/2;	
		}
		else if (startsWith(refLoc,"Bounding")){
			xRef = bBoxX;
			yRef = bBoxY;	
		}
		else if (startsWith(refLoc,"Reference")){
			xRef = fBoxX;
			yRef = fBoxY;	
		}
		yDistances = newArray();
		for (i=0;i<seqPixN;i++) yDistances[i] = pow((pow(xSeqCoords[i]-xRef,2) + pow(ySeqCoords[i]-yRef,2)),0.5);
		Array.getStatistics(yDistances, yDistances_min, yDistances_max, yDistances_mean, yDistances_stdDev);
		yRelDistances = newArray();
		for (i=0;i<seqPixN;i++) yRelDistances[i] = yDistances[i] - yDistances_min;
		if(lcf!=1){
			ySRelDistances = newArray();
			for (i=0;i<seqPixN;i++) ySRelDistances[i] = lcf * yRelDistances[i];
		}
	}
	Table.setColumn("Seq_coord_x", xSeqCoords);
	Table.setColumn("Seq_coord_y", ySeqCoords);
	Table.setColumn("Seq_dist\(px\)", xDistancesTotal);
	if(lcf!=1) Table.setColumn("Seq_dist\("+unit+"\)", xSDistancesTotal);
	if(continuous){
		Table.setColumn("Rel_dist\(px\)", yDistances);
		Table.setColumn("Rel_dist_norm\(px\)", yRelDistances);
		if(lcf!=1) Table.setColumn("Rel_dist_norm\("+unit+"\)", ySRelDistances);
		if(angleOut){
			Table.setColumn("Angle \(radians\)",radianAngles);
			Table.setColumn("Angle Offset \(radians\)",radianOffsets);
			Table.setColumn("Angle Offset \(degrees\)",degreeOffsets);
		}
	}
	if(showPixelSequence || diagnostics){
		for (i=0,j=0;i<seqPixN;i++){
			setPixel(xSeqCoords[i],ySeqCoords[i],j);
			if (j>240) j=1;
			j++;
		}
		rename(nTitle + "_pixelSequenceMap");
	}
	else if(!diagnostics) closeImageByTitle("unRavel_temp");
	Array.getStatistics(ySRelDistances, hStat_min, hStat_max, hStat_mean, hStat_stdDev);
	IJ.log("_________\n" + nTitle + " height statistics:\nmin = " + hStat_min + " " + unit + "\nmax = " + hStat_max + " " + unit + "\nrange = " + hStat_max-hStat_min + " " + unit +"\nmean = " + hStat_mean + " " + unit + "\nstd Dev = " + hStat_stdDev + " " + unit + "\nHavg/l = " + hStat_mean/lRef + "\n_________");
	if (hMap){
		Dialog.create("Height map options");
			Dialog.addNumber("Repeated lines to create 2D height map:",maxOf(50,round(seqPixN/10)),0,4,"rows");
			Dialog.addNumber("subsampling:",maxOf(1,round(seqPixN/4000)),0,10,"");
			Dialog.addCheckbox("Map should be saved as uncompressed TIFF; go ahead?",true);	
		Dialog.show();
			hMapN = Dialog.getNumber();
			subSamN = round(Dialog.getNumber());
			saveTIFF = Dialog.getCheckbox();
		subSeqPixN = round(seqPixN/subSamN);
		newImage("tempHMap", "32-bit black", subSeqPixN, 1, 1);
		for(i=0,j=0,k=0; i<seqPixN; i++){
			if (j==subSamN){
				setPixel(k,0,ySRelDistances[i]);
				k++;
				j=0;
			}
			j++;
		}
		run("Size...", "width="+subSeqPixN+" height="+hMapN+" depth=1 interpolation=None");
		run("Set Scale...", "distance="+subSeqPixN+" known="+lRef+" pixel=1 unit="+unit);
		run("Enhance Contrast...", "saturated=0"); /* required for viewable 32-bit Fiji image */
		rename(nTitle + "_hMap");
		closeImageByTitle("tempHMap");
		if(saveTIFF) saveAs("Tiff");
	}
	// else selectWindow(oTitle);
	setBatchMode("exit and display");
	exit();
	/* End of unraveling macro */		
/*
	( 8(|))  ( 8(|))  ( 8(|))  ASC Functions  @@@@@:-)  @@@@@:-)  @@@@@:-)
*/	
	function closeImageByTitle(windowTitle) {  /* Cannot be used with tables */
		/* v181002 reselects original image at end if open
		   v200925 uses "while" instead of "if" so that it can also remove duplicates
		*/
		oIID = getImageID();
        while (isOpen(windowTitle)) {
			selectWindow(windowTitle);
			close();
		}
		if (isOpen(oIID)) selectImage(oIID);
	}
	function guessBGMedianIntensity(){
		/* v220822 1st color array version (based on https://wsr.imagej.net//macros/tools/ColorPickerTool.txt) */
		iW = Image.width-1;
		iH = Image.height-1;
		interrogate = round(maxOf(1,(iW+iH)/200));
		if (bitDepth==24){red = 0; green = 0; blue = 0;}
		else int = 0;
		xC = newArray(0,iW,0,iW);
		yC = newArray(0,0,iH,iH);
		xAdd = newArray(1,-1,1,-1);
		yAdd = newArray(1,1,-1,-1);
		if (bitDepth==24){ reds = newArray(); greens = newArray(); blues = newArray();}
		else ints = newArray;
		for (i=0; i<xC.length; i++){
			for(j=0;j<interrogate;j++){
				if (bitDepth==24){
					v = getPixel(xC[i]+j*xAdd[i],yC[i]+j*yAdd[i]);
					reds = Array.concat(reds,(v>>16)&0xff);  // extract red byte (bits 23-17)
	           		greens = Array.concat(greens,(v>>8)&0xff); // extract green byte (bits 15-8)
	            	blues = Array.concat(blues,v&0xff);       // extract blue byte (bits 7-0)
				}
				else ints = Array.concat(ints,getValue(xC[i]+j*xAdd[i],yC[i]+j*yAdd[i]));
			}
		}
		midV = round((xC.length-1)/2);
		if (bitDepth==24){
			reds = Array.sort(reds); greens = Array.sort(greens); blues = Array.sort(blues);
			medianVals = newArray(reds[midV],greens[midV],blues[midV]);
		}
		else{
			ints = Array.sort(ints);
			medianVals = newArray(ints[midV],ints[midV],ints[midV]);
		}
		return medianVals;
	}
	function stripKnownExtensionFromString(string) {
		/*	Note: Do not use on path as it may change the directory names
		v210924: Tries to make sure string stays as string
		v211014: Adds some additional cleanup
		v211025: fixes multiple knowns issue
		v211101: Added ".Ext_" removal
		v211104: Restricts cleanup to end of string to reduce risk of corrupting path
		v211112: Tries to fix trapped extension before channel listing. Adds xlsx extension.
		*/
		string = "" + string;
		if (lastIndexOf(string, ".")>0 || lastIndexOf(string, "_lzw")>0) {
			knownExt = newArray("dsx", "DSX", "tif", "tiff", "TIF", "TIFF", "png", "PNG", "GIF", "gif", "jpg", "JPG", "jpeg", "JPEG", "jp2", "JP2", "txt", "TXT", "csv", "CSV","xlsx","XLSX","_"," ");
			kEL = lengthOf(knownExt);
			chanLabels = newArray("\(red\)","\(green\)","\(blue\)");
			unwantedSuffixes = newArray("_lzw"," ","  ", "__","--","_","-");
			uSL = lengthOf(unwantedSuffixes);
			for (i=0; i<kEL; i++) {
				for (j=0; j<3; j++){ /* Looking for channel-label-trapped extensions */
					ichanLabels = lastIndexOf(string, chanLabels[j]);
					if(ichanLabels>0){
						index = lastIndexOf(string, "." + knownExt[i]);
						if (ichanLabels>index && index>0) string = "" + substring(string, 0, index) + "_" + chanLabels[j];
						ichanLabels = lastIndexOf(string, chanLabels[j]);
						for (k=0; k<uSL; k++){
							index = lastIndexOf(string, unwantedSuffixes[k]);  /* common ASC suffix */
							if (ichanLabels>index && index>0) string = "" + substring(string, 0, index) + "_" + chanLabels[j];	
						}				
					}
				}
				index = lastIndexOf(string, "." + knownExt[i]);
				if (index>=(lengthOf(string)-(lengthOf(knownExt[i])+1)) && index>0) string = "" + substring(string, 0, index);
			}
		}
		unwantedSuffixes = newArray("_lzw"," ","  ", "__","--","_","-");
		for (i=0; i<lengthOf(unwantedSuffixes); i++){
			sL = lengthOf(string);
			if (endsWith(string,unwantedSuffixes[i])) string = substring(string,0,sL-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
		}
		return string;
	}
	function toWhiteBGBinary(windowTitle) { /* For black objects on a white background */
		/* Replaces binaryCheck function
		v220707
		*/
		selectWindow(windowTitle);
		if (!is("binary")) run("8-bit");
		/* Quick-n-dirty threshold if not previously thresholded */
		getThreshold(t1,t2);
		if (t1==-1)  {
			run("8-bit");
			run("Auto Threshold", "method=Default");
			setOption("BlackBackground", false);
			run("Make Binary");
		}
		if (is("Inverting LUT")) run("Invert LUT");
		/* Make sure black objects on white background for consistency */
		yMax = Image.height-1;	xMax = Image.width-1;
		cornerPixels = newArray(getPixel(0,0),getPixel(1,1),getPixel(0,yMax),getPixel(xMax,0),getPixel(xMax,yMax),getPixel(xMax-1,yMax-1));
		Array.getStatistics(cornerPixels, cornerMin, cornerMax, cornerMean, cornerStdDev);
		if (cornerMax!=cornerMin) restoreExit("Problem with image border: Different pixel intensities at corners");
		/*	Sometimes the outline procedure will leave a pixel border around the outside - this next step checks for this.
			i.e. the corner 4 pixels should now be all black, if not, we have a "border issue". */
		if (cornerMean<1) run("Invert");
	}
	function unCleanLabel(string) {
	/* v161104 This function replaces special characters with standard characters for file system compatible filenames.
	+ 041117b to remove spaces as well.
	+ v220126 added getInfo("micrometer.abbreviation").
	+ v220128 add loops that allow removal of multiple duplication.
	+ v220131 fixed so that suffix cleanup works even if extensions are included.
	+ v220616 Minor index range fix that does not seem to have an impact if macro is working as planned. v220715 added 8-bit to unwanted dupes. v220812 minor changes to micron and Ångström handling
	*/
		/* Remove bad characters */
		string= replace(string, fromCharCode(178), "\\^2"); /* superscript 2 */
		string= replace(string, fromCharCode(179), "\\^3"); /* superscript 3 UTF-16 (decimal) */
		string= replace(string, fromCharCode(0xFE63) + fromCharCode(185), "\\^-1"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string= replace(string, fromCharCode(0xFE63) + fromCharCode(178), "\\^-2"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string= replace(string, fromCharCode(181)+"m", "um"); /* micron units */
		string= replace(string, getInfo("micrometer.abbreviation"), "um"); /* micron units */
		string= replace(string, fromCharCode(197), "Angstrom"); /* Ångström unit symbol */
		string= replace(string, fromCharCode(0x212B), "Angstrom"); /* the other Ångström unit symbol */
		string= replace(string, fromCharCode(0x2009) + fromCharCode(0x00B0), "deg"); /* replace thin spaces degrees combination */
		string= replace(string, fromCharCode(0x2009), "_"); /* Replace thin spaces  */
		string= replace(string, "%", "pc"); /* % causes issues with html listing */
		string= replace(string, " ", "_"); /* Replace spaces - these can be a problem with image combination */
		/* Remove duplicate strings */
		unwantedDupes = newArray("8bit","8-bit","lzw");
		for (i=0; i<lengthOf(unwantedDupes); i++){
			iLast = lastIndexOf(string,unwantedDupes[i]);
			iFirst = indexOf(string,unwantedDupes[i]);
			if (iFirst!=iLast) {
				string = substring(string,0,iFirst) + substring(string,iFirst + lengthOf(unwantedDupes[i]));
				i=-1; /* check again */
			}
		}
		unwantedDbls = newArray("_-","-_","__","--","\\+\\+");
		for (i=0; i<lengthOf(unwantedDbls); i++){
			iFirst = indexOf(string,unwantedDbls[i]);
			if (iFirst>=0) {
				string = substring(string,0,iFirst) + substring(string,iFirst + lengthOf(unwantedDbls[i])/2);
				i=-1; /* check again */
			}
		}
		string= replace(string, "_\\+", "\\+"); /* Clean up autofilenames */
		/* cleanup suffixes */
		unwantedSuffixes = newArray(" ","_","-","\\+"); /* things you don't wasn't to end a filename with */
		extStart = lastIndexOf(string,".");
		sL = lengthOf(string);
		if (sL-extStart<=4 && extStart>0) extIncl = true;
		else extIncl = false;
		if (extIncl){
			preString = substring(string,0,extStart);
			extString = substring(string,extStart);
		}
		else {
			preString = string;
			extString = "";
		}
		for (i=0; i<lengthOf(unwantedSuffixes); i++){
			sL = lengthOf(preString);
			if (endsWith(preString,unwantedSuffixes[i])) {
				preString = substring(preString,0,sL-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
				i=-1; /* check one more time */
			}
		}
		if (!endsWith(preString,"_lzw") && !endsWith(preString,"_lzw.")) preString = replace(preString, "_lzw", ""); /* Only want to keep this if it is at the end */
		string = preString + extString;
		/* End of suffix cleanup */
		return string;
	}