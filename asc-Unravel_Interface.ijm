/* This macro unravels an outline (aimed at curved surfaces) so that x coordinates are relative to adjacent pixels and y coordinates are relative to a single point (or line - not activated yet).
	It is assumed that a pixel-width outline has already been created.
	Inspired by an idea proposed by Jeremy Adler <jeremy.adler@IGP.UU.SE> from an imageJ mailing list post on Monday, August 15, 2022 4:17 AM
	v220825 1st version.
	v221003 Adds option to create pseudo-height map for analysis in 3D analysis software like Gwyddion. Also report for evaluation length based in shape
	v221004 Replaces "None" with "Total_pixel-pixel_length" in evaluation length options
	v221005 Default median smoothing radius determined from initial bounding box. Map now has square pixels. Smoothed image can be generated independent of ref length. More reference location options.
	v221014 Restored ability to analyze line segments.
	v221107 Skeletonize is optional.
	v221108 Added initial menu to simplify instructions. Replaced sample length terminology with evaluation length to avoid confusion with sampling length. Added additional output columns.
	v221110 Outputs information about non-sequenced pixels (those that were missed from the continuous line because they were not the closest adjacent pixel in the search order.
	v221111 Evaluation lengths and highlighting of non-sequenced pixels are now shown as overlays on the pixel-sequence map if there are any non-sequenced pixels (even if the map was not requested).
	v221128 Incorrect start pixel fixed. Can now set intensity range for cut off and output;
	v221202 Replaced binary median with binary mean+threshold to speed up operation as suggested by post to ImageJ mailing list: http://imagej.nih.gov/ij/list.html by Herbie Gluender, 29. Nov 2022
	v230210 Fixed excessive space buffer creation and angle offset now relative to coordinate chosen in "Reference coordinate" dialog. Map can now be output using rotational sequence.
	v230211 Adds angle increment columns and directional filtering (useful if you have re-entrant angles).
	v230213 Adds column of sequential distance normalized to the evaluation length and adds option to output direction filtered results to csv file.
	v230214 Adds directional continuity flag to primary Results table, overlay display of filtered sequence, simple color options for overlays. Add zero degree start option and fixes disappearing Results window.
	v230228 Adds directional directional output from v230214 to horizontal and vertical lines - and fixes issues created with horizontal and vertical lines produced by v230214. Added color choices for overlays. Ra and Rq corrected relative to meanline.
	v230301 Changed name of pArea/pPerimeter ratio and more cosmetic changes to Dialog 1. b) Output menu cosmetic changes.
	v230303 Changed default spline fit for horizontal and vertical lines to 10% of pixels from 2% of perimeter.
	v230306 Option to crop overlay output image back to original dimensions of input image and sets this as default.
*/
	macroL = "Unravel_interface_v230306.ijm";
	setBatchMode(true);
	oTitle = getTitle;
	oID = getImageID();
	getPixelSize(unit, pixelWidth, pixelHeight);
	lcf=(pixelWidth+pixelHeight)/2; /* ---> add here the side size of 1 pixel in the new calibrated units (e.g. lcf=5, if 1 pixels is 5mm) <--- */
	if(lcf!=1) gotScale = true;
	else gotScale = false;
	nTitle = stripKnownExtensionFromString(oTitle);
	nTitle += "_unrav";
	dir = getInfo("image.directory");
	run("Duplicate...", "title=&nTitle ignore");
	if (!is("binary") || is("Inverting LUT") || getPixel(0,0)==0){
		if(getBoolean("This macro expects a binary image with white background, would you like to try a apply a quick fix?")) toWhiteBGBinary(nTitle);
		else ("Goodbye");
	}
	tempID = getImageID();
	getDimensions(oImageW, oImageH, oChannels, oSlices, oFrames);
	run("Select None");
	run("Create Selection");
	getSelectionBounds(minX, minY, widthS, heightS);
	/* The following section helps classify the object */
	borders = newArray(minX, minY, oImageH-heightS-minY,oImageW-widthS-minX);
	Array.getStatistics(borders,minBorder,maxBorder,null);
	pArea = getValue("Area raw");
	oSolidity = getValue("Solidity");
	oAR = getValue("AR");
	oAngle = getValue("Angle");
	pPerimeter = getValue("Perim. raw");
	pxPpxARatio = pPerimeter/pArea;
	run("Select None");
	run("Fill Holes");
	getRawStatistics(nPixels, meanPx, minPx, maxPx);
	pFArea = (maxPx/meanPx-1)*nPixels;
	run("Undo");
	if (pxPpxARatio>0.95){
		if (pFArea/pArea>=1.1) objectType = "Continuous_outline";
		else if (oSolidity<1){
			if (oAngle<45 || oAngle>135) objectType = "Horizontal_line";
			else objectType = "Vertical_line";
		}
		else objectType = "Something_else";
	}
	else if (pFArea/pArea<1.1 || oSolidity>0.5) objectType = "Solid_object";
	if (objectType=="Solid_object") safeMargin = round(pPerimeter/40);
	else {
		run("Create Selection");
		setOption("BlackBackground", false);
		run("Skeletonize");
		pPerimeter = getValue("Perim. raw");
		pArea = getValue("Area raw");
		run("Undo");
		safeMargin = round(pArea/40);
		run("Select None");
	}
	if (safeMargin>oImageW && safeMargin>oImageH) showMessage("Problem with safeMargin size \(" + safeMargin + "\), minimum border space = " + minBorder);
	/* Make sure canvas is large enough to accommodate any smoothing or fits */
	if (minX<safeMargin || (oImageW-(minX+widthS))<safeMargin) newWidth = 2*safeMargin+oImageW;
	else newWidth = oImageW;
	if (minY<safeMargin || (oImageH-(minY+heightS))<safeMargin) newHeight = 2*safeMargin+oImageH;
	else newHeight = oImageH;
	if (newHeight!=oImageH || newWidth!=oImageW)	expCanvas = true; /* Could use as a contraction flag for a future option */
	else expCanvas = false;
	if (expCanvas) run("Canvas Size...", "width=&newWidth height=&newHeight position=Center");
	revertCanvas = expCanvas;
	revertCoords = expCanvas;
	run("Create Selection");
	pX = round(getValue("X raw"));
	pY = round(getValue("Y raw"));
	run("Select None");
	getDimensions(imageW, imageH, oChannels, oSlices, oFrames);
	objectTypes = newArray("Continuous_outline","Solid_object","Horizontal_line","Vertical_line","Something_else");
	setBatchMode("exit and display");
	grayChoices = newArray("white", "black", "off-white", "off-black", "light_gray", "gray", "dark_gray");
	colorChoicesStd = newArray("red", "green", "blue", "cyan", "magenta", "yellow", "pink", "orange", "violet");
	colorChoicesMod = newArray("garnet", "gold", "aqua_modern", "blue_accent_modern", "blue_dark_modern", "blue_modern", "blue_honolulu", "gray_modern", "green_dark_modern", "green_modern", "green_modern_accent", "green_spring_accent", "orange_modern", "pink_modern", "purple_modern", "red_n_modern", "red_modern", "tan_modern", "violet_modern", "yellow_modern");
	colorChoicesNeon = newArray("jazzberry_jam", "radical_red", "wild_watermelon", "outrageous_orange", "supernova_orange", "atomic_tangerine", "neon_carrot", "sunglow", "laser_lemon", "electric_lime", "screamin'_green", "magic_mint", "blizzard_blue", "dodger_blue", "shocking_pink", "razzle_dazzle_rose", "hot_magenta");
	colorChoices = Array.concat(colorChoicesStd, colorChoicesMod, colorChoicesNeon, grayChoices);
	Dialog.create("Unraveling options 1: \(" + macroL + "\)");
		Dialog.addMessage("This macro currently only works on individual objects",12,"#782F40");
		if(expCanvas) Dialog.addMessage("The working image has been expanded to accommodate curve fitting options");
		if(expCanvas){
			Dialog.setInsets(-1, 20, 1);
			Dialog.addCheckbox("Revert output canvas to original dimensions",revertCanvas);
			Dialog.addCheckbox("Revert output coordinates to original coordinates",revertCoords);
			Dialog.setInsets(15, 20, 5);
		}
		if(oChannels+oSlices+oFrames!=3) Dialog.addMessage("Warning: This macro has only been tested on single slice-frame-channel images",12,"red");
		if (isOpen("Results")) Dialog.addCheckbox("Close the currently open Results window?",true);
		Dialog.addRadioButtonGroup("Object type:",objectTypes,objectTypes.length,1,objectType);
		message2 = "Identified object type: " + objectType + "       from:";
		message2 += "\nTotal pixels:                   " + pArea + "\nBlack pixels after fill:   " + pFArea;
		message2 += "\nAspect ratio:                   " + oAR + "\nPerimeter:                       " + pPerimeter + " pixels";
		message2 += "\nSolidity:                            " + oSolidity + "\nAngle:                              " + oAngle + " degrees";
		message2 += "\npPer.:pArea ratio:          " + pxPpxARatio;
		Dialog.addMessage(message2);
	Dialog.show;
		if(expCanvas){
			revertCanvas = Dialog.getCheckbox();
			revertCoords = Dialog.getCheckbox();
		} 
		if (isOpen("Results")){
			if(Dialog.getCheckbox()) while (isOpen("Results")) close("Results");
		} 
		objectType = Dialog.getRadioButton();
	if (objectType=="Something_else") exit("Sorry, I am not ready for 'something else' yet");
	if (startsWith(objectType,"Continuous") || startsWith(objectType,"Solid")) continuous = true;
	else continuous = false;
	if (!endsWith(objectType,"_line")){
		refLengths = newArray("Total_pixel-pixel_length","Ellipse_perimeter","Circle_perimeter","Object_perimeter","Median-smooth_object_perimeter");
		defRef = 1;
	}
	else{
		refLengths = newArray("Total_pixel-pixel_length","First-to-last-in-sequence_distance", "Sub-sample_spline-fit");
		defRef = 2;
	}
	smoothKeep = false;
	smoothN = 0;
		Dialog.create("Unraveling options 2 \(" + macroL + "\)");
		Dialog.addRadioButtonGroup("Output evaluation length \(used for horizontal map scale\):",refLengths,refLengths.length,1,refLengths[defRef]);
		if (!endsWith(objectType,"_line")){
			if (startsWith(objectType, "Solid")) defSmoothN = minOf(1000,round(pPerimeter/50)); /* median smoothing limited to max of 1000 */
			else defSmoothN = minOf(1000,round(pArea/50)); /* median smoothing limited to max of 1000 */
			Dialog.addCheckbox("Create median smoothed object \(i.e. physical waviness\)",false);
			Dialog.addNumber("Radius for median smoothing \(mean filter method\)",defSmoothN,0,4,"pixels \(max 1000\)");
			if (startsWith(objectType, "Solid")) mText = "Default median radius of " + defSmoothN + " pixels based on 2% of original perimeter \(" + pPerimeter + " pixels\)";
			else mText = "Default median radius of " + defSmoothN + " pixels based on 2% of original perimeter \(" + pArea + " pixels\)";
			if (defSmoothN==100) mText += ", limited to a maximum of 1000";
			Dialog.addMessage(mText);
		}
		else {
			defSmoothN = minOf(1000,round(pArea/10));
			Dialog.addNumber("Sub-sample interval for spline",defSmoothN,0,4,"pixels");
			Dialog.addMessage("Default interval of " + defSmoothN + " pixels based on 10% of original "+pArea+" pixels in line\n");
		}
		iFitCol = indexOfArray(colorChoices,call("ij.Prefs.get", "asc_unravel.fit.col","screamin'_green"),2);
		Dialog.addChoice("Overlay color for fits",colorChoices,colorChoices[iFitCol]);
		/* Fewer outline-skeletonized pixels will be missed from the unravel sequence, so skeletonizing the line/outline is the default setting: */
		Dialog.addCheckbox("Skeletonize outline/interface line \(could remove significant pixels\)",true); /* removes redundant pixels . . . but are they? */
		Dialog.addCheckbox("Create pseudo-height map from interface that can be used in other software",true);
		Dialog.addCheckbox("Diagnostics",false);
	Dialog.show;
		refLength = Dialog.getRadioButton();
		if (!endsWith(objectType,"_line")) smoothKeep = Dialog.getCheckbox();
		smoothN = minOf(1000,Dialog.getNumber());
		fitCol = Dialog.getChoice();
		call("ij.Prefs.set", "asc_unravel.fit.col",fitCol);
		skelGo = Dialog.getCheckbox();
		hMap = Dialog.getCheckbox();
		diagnostics = Dialog.getCheckbox();
	if(!diagnostics) setBatchMode(true);
	selectImage(tempID);
	if (startsWith(objectType,"Solid")) run("Outline");
	if (skelGo) run("Skeletonize");
	run("Select None");
	refLTitle = nTitle + "_RefLength_temp";
	run("Duplicate...", "title=&refLTitle ignore");
	procTitle = nTitle + "_as-processed";
	run("Duplicate...", "title=&procTitle ignore");
	selectImage(tempID);
	run("Create Selection");
	getSelectionBounds(minBX, minBY, widthB, heightB);
	pArea  = getValue("Area raw");
	maxBX = minBX + widthB;
	maxBY = minBY + heightB;
	bgY = getPixel(0, pY);
	for(i=1;i<imageW;i++){
		if (getPixel(i,pY)!=bgY){
			horizX = i;
			i = imageW;
		}
	}
	for(i=1;i<imageH;i++){
		if (getPixel(pX,i)!=bgY){
			vertY = i;
			i = imageH;
		}
	}
	run("Select None");
	xSeqCoords = newArray();
	ySeqCoords = newArray();
	for(topY=minBY,done=false;topY<maxBY+1 && !done; topY++){
		for(topX=minBX;topX<maxBX+1 && !done; topX++) if (getPixel(topX,topY)!=255)	done = true;
	}
	topX -= 1; /* topX++ correct etc. */
	topY -= 1;
	for(leftX=minBX,done=false;leftX<maxBX+1 && !done; leftX++){
		for(leftY=minBY;leftY<maxBY+1 && !done; leftY++) if (getPixel(leftX,leftY)!=255)	done = true;
	}
	leftX -= 1; /* leftX++ correct etc. */
	leftY -= 1;
	startCoordOptions = newArray("Manual entry");
	if (objectType=="Horizontal_line") startCoordOptions = Array.concat("Left  pixel \("+leftX+","+leftY+"\)",startCoordOptions);
	else if (objectType=="Vertical_line") startCoordOptions = Array.concat("Top pixel \("+topX+","+topY+"\)",startCoordOptions);
	else startCoordOptions = Array.concat("Leftmost  pixel \("+leftX+","+leftY+"\)","Topmost pixel \("+topX+","+topY+"\)","90 degree left edge \("+horizX+","+pY+"\)","Zero degrees \(top\) edge \("+pX+","+vertY+"\)",startCoordOptions);
	Dialog.create("Unraveling options 3: \(" + macroL + "\)");
		Dialog.addRadioButtonGroup("Starting point:",startCoordOptions,startCoordOptions.length,1,startCoordOptions[0]);
		Dialog.addNumber("Intensity cut off and output intensity minimum",20,0,4,"");
		Dialog.addNumber("Output intensity maximum",180,0,4,"");
		Dialog.addNumber("Manual start x",0,0,3,"pixels");
		Dialog.addNumber("Manual start y",0,0,3,"pixels");
		Dialog.addNumber("Pixel search range in plus and minus pixels",6,0,3,"pixels");
		if (!endsWith(objectType,"_line")){
			Dialog.addCheckbox("Try to start clockwise?",true);
			Dialog.addCheckbox("Output rotational sequence values",continuous);
		}
		Dialog.addCheckbox("Keep pixel sequence and spline fit image",true);
		Dialog.setInsets(-3, 15, 3);
		Dialog.addMessage("Pixel sequence and spline fit image will always be\nkept if there are any unsequenced pixels");
		Dialog.addCheckbox("Use overlay to highlight locations of unsequenced pixels",true);
		iUSCol = indexOfArray(colorChoices,call("ij.Prefs.get", "asc_unravel.unseqpixels.col","dodger_blue"),0);
		Dialog.addChoice("Overlay color for highlighting unsequenced pixels",colorChoices,colorChoices[iUSCol]);
	Dialog.show;
		startCoordOption = Dialog.getRadioButton();
		minInt = Dialog.getNumber();
		maxInt = Dialog.getNumber();
		x = Dialog.getNumber();
		y = Dialog.getNumber();
		kernelR = Dialog.getNumber();
		if (!endsWith(objectType,"_line")){
			clockwise = Dialog.getCheckbox();
			angleOut = Dialog.getCheckbox();
		}
		else {
			clockwise = false;
			angleOut = false;
		}
		keepPixelSequence = Dialog.getCheckbox();
		unsequencedOverlay = Dialog.getCheckbox();
		unsequencedOverlayColor = Dialog.getChoice();
		call("ij.Prefs.set", "asc_unravel.unseqpixels.col",unsequencedOverlayColor);
	if (!diagnostics) setBatchMode(true);
	// getRawStatistics(nPixels, meanPx, minPx, maxPx);
	if (startsWith(startCoordOption,"Top")){
		x = topX;
		y = topY;
	}
	else if (startsWith(startCoordOption,"Left")){
		x = leftX;
		y = leftY;
	}
	else if (startsWith(startCoordOption,"90")){
		x = horizX;
		y = pY;
	}
	else if (startsWith(startCoordOption,"Zero")){
		x = pX;
		y = vertY;
	}
	startPixelInt = getPixel(x,y);
	if (startPixelInt>maxInt) exit ("Start pixel \(" + x + ", " + y + "\) intensity = " + startPixelInt);
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
	selectWindow(nTitle);
	setPixel(x,y,minInt); /* Removes start pixel from search */
	nSearchPxls = xSearchPxls.length;
	for(i=1,k=0; i<pArea && !done; i++){
		for(j=0,gotPix=false; j<nSearchPxls+1 && !gotPix; j++){
			if(j==nSearchPxls) done = true;
			else{
				testX = xSeqCoords[k] + xSearchPxls[j];
				testY = ySeqCoords[k] + ySearchPxls[j];
				testI = getPixel(testX,testY);
				if (testI<minInt){
					k++;
					xSeqCoords[k] = testX;
					ySeqCoords[k] = testY;
					newI = minInt + k*maxInt/pArea;
					setPixel(xSeqCoords[k],ySeqCoords[k],newI); /* removes found contiguous pixel from search */
					if (diagnostics) print(k,newI,xSeqCoords[k],ySeqCoords[k]);
					gotPix = true;
				}
			}
		}
	}
	updateDisplay();
	Array.getStatistics(xSeqCoords, xSeqCoords_min, xSeqCoords_max, xSeqCoords_mean, xSeqCoords_stdDev);
	Array.getStatistics(ySeqCoords, ySeqCoords_min, ySeqCoords_max, ySeqCoords_mean, ySeqCoords_stdDev);
	seqPixN = xSeqCoords.length;
	if (diagnostics) print(seqPixN + "coordinates in sequence");
	ptpDistances = newArray(0,0);
	for (i=1;i<seqPixN;i++){
		relI = i-1;
		if(relI<1){
			if(continuous) iD = seqPixN+relI-1;
			else iD = 0;
		}
		else iD = i-1;
		ptpDistances[i] = pow((pow(xSeqCoords[i]-xSeqCoords[iD],2) + pow(ySeqCoords[i]-ySeqCoords[iD],2)),0.5);
	}
	ptpDistancesTotal = newArray(0,0);
	if(gotScale){
		ptpSDistances = newArray(0,0);
		ptpSDistancesTotal = newArray(0,0);
	} 
	for (i=1;i<seqPixN;i++){
		ptpDistancesTotal[i] = ptpDistancesTotal[i-1] + ptpDistances[i];
		if(gotScale) {
			ptpSDistances[i] = lcf * ptpDistances[i];
			ptpSDistancesTotal[i] = lcf * ptpDistancesTotal[i];
		}
	}
	Array.getStatistics(ptpDistancesTotal, ptpDistancesTotal_min, ptpDistancesTotal_max, ptpDistancesTotal_mean, ptpDistancesTotal_stdDev);
	/* The following section provides an estimate of the total evaluation length */
	selectWindow(refLTitle);
	if(refLength=="Total_pixel-pixel_length") lRef = ptpDistancesTotal_max;
	else if(startsWith(refLength,"First-to-last")) lRef = lcf * sqrt(pow(xSeqCoords[0]-xSeqCoords[seqPixN-1],2) + pow(ySeqCoords[0]-ySeqCoords[seqPixN-1],2));
	else if(startsWith(refLength,"Sub-sample_spline-fit")){
		seqSubN = round(seqPixN/smoothN);
		subLXs = Array.resample(xSeqCoords,seqSubN);
		subLYs = Array.resample(ySeqCoords,seqSubN);
		if(diagnostics){
			IJ.log("subsampled line x and y coordinates for approximate evaluation length");
			Array.print(subLXs);
			Array.print(subLYs);
		}
		makeSelection("sub-sampled line", subLXs,subLYs);
		run("Fit Spline");
		lRef = getValue("Length");
		if(lRef==NaN){  /* if spline fit does not work . . .  */
			IJ.log("Spline fit fail; total sub-sampled point-point distances used for evaluation length");
			x1 = subLXs[0];
			y1 = subLYs[0];
			for(i=0,lRef=0;i<subLXs.length-1;i++){
				x2 = subLXs[i+1];
				y2 = subLYs[i+1];
				lRef += sqrt(pow(x2-x1,2) + pow(y2-y1,2));
				x1 = x2;
				y1 = y2;
			}
			if(gotScale) lRef*= lcf;
		}
		run("Select None");
		selectWindow(nTitle);
		run("Restore Selection");
		Roi.setName("Spline fit to " + smoothN + " pixel sub-sampling");
		Overlay.addSelection(fitCol, minOf(1,maxOf(2,(imageW+imageH)/400)));
		suffix = replace(refLength,"spline-fit",smoothN + "pixel-spline-fit");
		nTitle += "+" + suffix;
		rename(nTitle);
		run("Select None");
	}
	else {
		selectWindow(refLTitle);
		run("Fill Holes");  /* allows rest to work with outline or solid object */
		if(refLength=="Ellipse_perimeter" || refLength=="Circle_perimeter"){
			run("Create Selection");
			if(refLength=="Ellipse_perimeter")	run("Fit Ellipse");
			else run("Fit Circle");
			lRef = getValue("Perim.");
			run("Select None");
		}
		else if(startsWith(refLength,"Median") || smoothKeep){
			/* Replaced binary median with binary mean+threshold to speed up operation as suggested by post to ImageJ mailing list: http://imagej.nih.gov/ij/list.html by Herbie Gluender, 29. Nov 2022 */
			run("Mean...", "radius=&smoothN"); /* mean filter much faster than binary median in ImageJ */
			setThreshold(0, 127, "raw"); /* binary median (majority filter) */
			run("Convert to Mask");
			medianT = nTitle + "_median" + smoothN;
			if(smoothKeep) run("Duplicate...", "title=&medianT ignore");
			run("Create Selection");
			if(startsWith(refLength,"Median")) lRef = getValue("Perim.");
		}
		else run("Create Selection");
		getSelectionBounds(fMinX, fMinY, fWidthS, fHeightS);
		fBoxX = fMinX + fWidthS/2;
		fBoxY = fMinY + fHeightS/2;
		if(refLength=="Horizontal_distance") lRef = lcf * fWidthS;
		else if(refLength=="Vertical_distance") lRef = lcf * fHeightS;
		else if(refLength!="Ellipse_perimeter" && refLength!="Circle_perimeter" && !startsWith(refLength,"Median")){
			run("Create Selection");
			run("Clear", "slice");
			run("Invert");
			run("Clear Outside");
			List.setMeasurements;
			// print(List.getList); // list all measurements
			lRef = List.getValue("Perim.");
		}
		run("Select None");
		selectWindow(nTitle);
		run("Restore Selection");
		Roi.setName("Fit");
		Overlay.addSelection(fitCol, minOf(1,maxOf(2,(imageW+imageH)/400)));
		suffix = replace(refLength,"Median",smoothN + "-pixel-Median");
		nTitle += "+" + suffix;
		rename(nTitle);
		run("Select None");
	}
	lName = replace(refLength,"_"," ");
	lName = replace(lName,"Median-smooth","Median \(" + smoothN + " pxl\) smoothed")	;
	IJ.log("For " + oTitle + ":\n" + lName + " = " + lRef + " " + unit);
	if(continuous){
		refLocs = newArray("Sequential_pixel_centroid","Object_center","Image_center");
		dimensionsText = "Sequential pixel centroid: x = " + xSeqCoords_mean + ", y = " + ySeqCoords_mean + "\nObject center: x = " + pX + ", y = " + pY+ "\nImage center: x = " + imageW/2 + ", y = " + imageH/2;
		Dialog.create("Reference coordinate \(" + macroL + "\)");
			if(refLength!="Total_pixel-pixel_length"){
				refLocs = Array.concat(refLocs,"Reference_shape_center");
				refShapeName = replace(lName,"perimeter","");
				dimensionsText += "\nReference shape \(" + refShapeName + "\) center: x = " + fBoxX + ", y = " + fBoxY;
			}
			refLocs = Array.concat(refLocs,"Arbitrary_coordinates");
			Dialog.addMessage(dimensionsText);
			Dialog.addRadioButtonGroup("Reference location for height and angles:",refLocs,refLocs.length,1,refLocs[1]);
			Dialog.addNumber("Arbitrary x", 0,0,10,"pixels");
			Dialog.addNumber("Arbitrary y", 0,0,10,"pixels");
			Dialog.addString("Column name for distance to reference","Height",10);
			Dialog.setInsets(-5, 20, 0);
			Dialog.addMessage("Column name, i.e. 'Height', should be table compatible");
		Dialog.show;
			refLoc = Dialog.getRadioButton();
			xRef = Dialog.getNumber();
			yRef = Dialog.getNumber();
			distName = Dialog.getString;
			if (distName=="") distName = "Height";
		if (startsWith(refLoc,"Sequential")){
			xRef = xSeqCoords_mean;
			yRef = ySeqCoords_mean;
		}
		else if (startsWith(refLoc,"Object")){
			xRef = pX;
			yRef = pY;
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
	}
	else if (endsWith(objectType,"_line")) {
		xRef = xSeqCoords_min;
		yRef = ySeqCoords_min;
		if (startsWith(objectType,"Vert")) distName = "Horiz_dist";
		else if (startsWith(objectType,"Horiz")) distName = "Vert_dist";
		else distName = "Height";
	}
	else exit("Unidentified reference location");
	IJ.log("Reference locations: x = " + xRef + ", y = " + yRef);
	if(revertCoords) IJ.log("\(Reference locations for original image: x = " + xRef-safeMargin + ", y = " + yRef-safeMargin + "\)");
	if (!endsWith(objectType,"_line")){
		radianAngles = newArray();
		degreeAngles = newArray();
		radianOffsets = newArray();
		radianIncrements = newArray(0,0);
		degreeOffsets = newArray();
		degreeIncrements = newArray(0,0);
		for (i=0;i<seqPixN;i++){
			radianAngles[i] = atan2(xRef-xSeqCoords[i],yRef-ySeqCoords[i]);
			radOff = radianAngles[i] - radianAngles[0];
			if (radOff<0) radianOffsets[i] = 2*PI + radOff;
			else radianOffsets[i] = radOff;
			degreeOffsets[i] = radianOffsets[i] * 180/PI;
			if (i>0){
				radInc = radianAngles[i] - radianAngles[i-1];
				if(radInc>PI) radInc -= 2*PI;
				else if (radInc<-PI) radInc += 2*PI;
				radianIncrements[i] = radInc;
				degreeIncrements[i] = radInc * 180/PI;
			}
			degreeAngles[i] = radianAngles[i] * 180/PI;
		}
		Array.getStatistics(degreeIncrements, degreeIncrements_min, degreeIncrements_max, degreeIncrements_mean, degreeIncrements_stdDev);
		if(degreeIncrements_mean<0){
			clockwiseIncr = true;
			IJ.log("Apparent direction clockwise; mean advance " + degreeIncrements_mean + " degrees");
		}
		else {
			clockwiseIncr = false;
			IJ.log("Apparent direction anticlockwise; mean advance " + degreeIncrements_mean + " degrees");
		}
	}
	relDistances = newArray();
	if (startsWith(objectType,"Vert")) for (i=0;i<seqPixN;i++) relDistances[i] = xSeqCoords[i];
	else if (startsWith(objectType,"Horiz")) for (i=0;i<seqPixN;i++) relDistances[i] = imageH - ySeqCoords[i]; /* correct to make increasing height upwards */
	else for (i=0;i<seqPixN;i++) relDistances[i] = pow((pow(xSeqCoords[i]-xRef,2) + pow(ySeqCoords[i]-yRef,2)),0.5);
	Array.getStatistics(relDistances, relDistances_min, relDistances_max, relDistances_mean, relDistances_stdDev);
	normRelDistances = newArray();
	normRelDistSqs = newArray();
	for (i=0;i<seqPixN;i++){
		normRelDistances[i] = relDistances[i] - relDistances_min;
		normRelDistSqs[i] = pow(normRelDistances[i],2);
	}
	normRelDistances = newArray();
	normRelDistanceFMeans = newArray();
	normRelDistFMeanSqs = newArray();
	for (i=0;i<seqPixN;i++) normRelDistances[i] = relDistances[i] - relDistances_min;
	Array.getStatistics(normRelDistances,null,null,normRelDistances_mean,null);
	for (i=0;i<seqPixN;i++){
		normRelDistanceFMeans[i] = abs(normRelDistances[i]-normRelDistances_mean);
		normRelDistFMeanSqs[i] = pow(normRelDistanceFMeans[i],2);
	}
	if(gotScale){
		sNormRelDistances = newArray();
		sNormRelDistanceFMeans = newArray();
		sNormRelDistFMeanSqs = newArray();
		for (i=0;i<seqPixN;i++){
			sNormRelDistances[i] = lcf * normRelDistances[i];
			sNormRelDistanceFMeans[i] = lcf * normRelDistanceFMeans[i];
			sNormRelDistFMeanSqs[i] = pow(sNormRelDistanceFMeans[i],2);
		}
	}
	Table.setColumn("Seq_coord_x", xSeqCoords);
	Table.setColumn("Seq_coord_y", ySeqCoords);
	Table.setColumn("Incr_dist\(px\)", ptpDistances);
	Table.setColumn("Seq_dist\(px\)", ptpDistancesTotal);
	if(gotScale){
		Table.setColumn("Incr_dist\("+unit+"\)", ptpSDistances);
		Table.setColumn("Seq_dist\("+unit+"\)", ptpSDistancesTotal);
	} 
	if(continuous){
		Table.setColumn(distName + "\(px\)", relDistances);
		Table.setColumn(distName + "_norm\(px\)", normRelDistances);
		if(gotScale){
			Table.setColumn(distName + "_norm\("+unit+"\)", sNormRelDistances);
			Table.setColumn(distName + "_norm_from_Mean\("+unit+"\)", sNormRelDistanceFMeans);
			Table.setColumn(distName + "_norm_from_Mean^2\("+unit+"^2\)",sNormRelDistFMeanSqs);
		}
		else Table.setColumn(distName + "_normFromMean^2",normRelDistFMeanSqs);
		if(angleOut){
			Table.setColumn("Angle \(radians\)",radianAngles);
			Table.setColumn("Angle \(degrees\)",degreeAngles);
			Table.setColumn("Angle Offset \(radians\)",radianOffsets);
			Table.setColumn("Angle Offset \(degrees\)",degreeOffsets);
			Table.setColumn("Angle Incr. \(radians\)",radianIncrements);
			Table.setColumn("Angle Incr. \(degrees\)",degreeIncrements);
		}
	}
	else {
		Table.setColumn(distName + "\(px\)", relDistances);
		Table.setColumn(distName + "_norm\(px\)", normRelDistances);
		if(gotScale){
			Table.setColumn(distName + "_norm\("+unit+"\)", sNormRelDistances);
			Table.setColumn(distName + "_norm_from_Mean\("+unit+"\)", sNormRelDistanceFMeans);
			Table.setColumn(distName + "_norm_from_Mean^2\("+unit+"^2\)", sNormRelDistFMeanSqs);
		}
		else Table.setColumn(distName + "_norm^2",normRelDistSqs);
	}
	if (!endsWith(objectType,"_line")) clockwise = clockwiseIncr;
	Dialog.create("Directional filtering and height map options: " + macroL);
		Dialog.addMessage(seqPixN + " sequential interface pixels found");
		Dialog.addCheckbox("Filter out direction discontinuity (skip re-entrant surfaces)?",continuous);
		/* if the unravelling points change direction they are ignored until the previous angular extent is exceeded */
		Dialog.setInsets(-2, 40, 0); 
		Dialog.addCheckbox("Re-normalize directional dataset as selected above",continuous);
		Dialog.setInsets(-2, 40, 0);
		Dialog.addCheckbox("Save directional dataset as selected above",continuous);
		Dialog.setInsets(-2, 40, 0);
		Dialog.addCheckbox("Identify filtered pixel set on sequence image",continuous);
		iFiltCol = indexOfArray(colorChoices,call("ij.Prefs.get", "asc_unravel.filtered.col","outrageous_orange"),1);
		Dialog.addChoice("Color for filtered pixel overlay",colorChoices,colorChoices[iFiltCol]);
		if (hMap){
			Dialog.addNumber("Eval. length \(from " + refLength + "\) to embed as horizontal scale:",lRef,10,14,unit);
			Dialog.addNumber("Repeated lines to create 2D height map:",maxOf(50,round(seqPixN/10)),0,4,"rows");
			Dialog.addNumber("Sub-sample measurements \(1 = none\):",maxOf(1,round(seqPixN/4000)),0,10,"");
			Dialog.addCheckbox("Save height map \(should be saved as uncompressed TIFF\)",true);
		}
		if (angleOut){
			Dialog.addCheckbox("Sort data by offset angle (not useful if direction filtered)?",false);
			if(clockwiseIncr) Dialog.addCheckbox("Leave as clockwise direction \(clockwise from analysis\)?",clockwiseIncr);
			else Dialog.addCheckbox("Reverse to clockwise \(anti-clockwise from analysis\)?",clockwiseIncr);
		}
	Dialog.show();
		oneDirection = Dialog.getCheckbox();
		filteredNorm =  minOf(oneDirection,Dialog.getCheckbox());
		filteredCSV =  minOf(oneDirection,Dialog.getCheckbox());
		filteredOverlay =  minOf(oneDirection,Dialog.getCheckbox());
		filteredOverlayCol = Dialog.getChoice();
		call("ij.Prefs.set", "asc_unravel.filtered.col",filteredOverlayCol);
		if (hMap){
			lRef = Dialog.getNumber();
			hMapN = Dialog.getNumber();
			subSamN = maxOf(1,round(Dialog.getNumber()));
			saveTIFF = Dialog.getCheckbox();
		}
		if (angleOut){
			sortByAngle = Dialog.getCheckbox();
			clockwise = Dialog.getCheckbox();
		}
		else sortByAngle = false; 
	if(gotScale) {
		outPTPDists = ptpSDistances;
		outPTPDistTotals = ptpSDistancesTotal;
		evalLF = ptpSDistancesTotal[seqPixN-1]/lRef;
		outPTPDistTotalEvals = newArray(0,0);
		for (i=0;i<seqPixN;i++) outPTPDistTotalEvals[i] = ptpSDistancesTotal[i]/evalLF;
		Table.setColumn("Seq_dist_NormToEval\("+unit+"\)", outPTPDistTotalEvals);
		Table.update;
		outRelDists = sNormRelDistances;
		outRelDistFMeans = sNormRelDistanceFMeans;
		outRelDistFMeanSqs = sNormRelDistFMeanSqs;
	}
	else{
		outPTPDists = ptpDistances;
		outPTPDistTotals = ptpDistancesTotal;
		outRelDists = normRelDistances;
		outRelDistFMeans = normRelDistanceFMeans;
		outRelDistFMeanSqs = normRelDistFMeanSqs;
	} 
	if (oneDirection) {
		oneDirOutPTPDists = newArray(0,0);
		oneDirOutPTPDistTotals = newArray(0,0);
		oneDirOutRelDists = newArray(outRelDists[0],0);
		oneDirOutRelDistFMeans = newArray(outRelDistFMeans[0],0);
		oneDirOutRelDistFMeanSqs = newArray(outRelDistFMeanSqs[0],0);
		oneDirOutPTPDistTotalEvals = newArray(0,0);
		oneDirXSeqCoords = newArray(xSeqCoords[0],0);
		oneDirYSeqCoords = newArray(xSeqCoords[0],0);
		oneDirOriginalIDs = newArray(0,0);
		if(gotScale) oneDirOutRelDistsSq = newArray();
		if(startsWith(objectType,"Vert") || startsWith(objectType,"Horiz")){
			oneDirOrthOffsets = newArray(0,0);
			oneDirOrthIncrements = newArray(0,0);
			for(i=0,k=0,orthDist=-1; i<seqPixN; i++){
				if (startsWith(objectType,"Vert")) orthOffset = ySeqCoords[i]-ySeqCoords_min;
				else orthOffset = xSeqCoords[i]-xSeqCoords_min;
				if (orthOffset>orthDist){
					if(i>0){
						orthDist = orthOffset;
						oneDirOrthOffsets[k] = orthDist;
						oneDirOrthIncrements[k] = orthDist - oneDirOrthOffsets[k-1];
					}
					Table.set("Directional_continuity",i,true);
					oneDirOutPTPDists[k] = outPTPDists[i];
					oneDirOutPTPDistTotals[k] = outPTPDistTotals[i];
					oneDirOutRelDists[k] = outRelDists[i];
					oneDirOutRelDistFMeans[k] = outRelDistFMeans[i];
					oneDirOutRelDistFMeanSqs[k] = outRelDistFMeanSqs[i];
					oneDirOutPTPDistTotalEvals[k] = outPTPDistTotalEvals[i];
					oneDirXSeqCoords[k] = xSeqCoords[i];
					oneDirYSeqCoords[k] = ySeqCoords[i];
					oneDirOriginalIDs[k] = i;
					k++;
				}
				else Table.set("Directional_continuity",i,false);
			}
		}
		else {
			if(clockwise) angle = 360;
			else angle = -1;
			oneDirOutDegreeOffsets = newArray(0,0);
			oneDirOutDegreeIncrements = newArray(0,0);
			for(i=0,k=0; i<seqPixN; i++){
				if((clockwise && degreeOffsets[i]<angle) || (!clockwise && degreeOffsets[i]>angle)){
					if(i>0){
						angle = degreeOffsets[i];
						oneDirOutDegreeOffsets[k] = angle;
						oneDirOutDegreeIncrements[k] = abs(oneDirOutDegreeOffsets[k]-oneDirOutDegreeOffsets[k-1]);
					}
					Table.set("Directional_continuity",i,true);
					oneDirOutPTPDists[k] = outPTPDists[i];
					oneDirOutPTPDistTotals[k] = outPTPDistTotals[i];
					oneDirOutRelDists[k] = outRelDists[i];
					oneDirOutRelDistFMeans[k] = outRelDistFMeans[i];
					oneDirOutRelDistFMeanSqs[k] = outRelDistFMeanSqs[i];
					oneDirOutPTPDistTotalEvals[k] = outPTPDistTotalEvals[i];
					oneDirXSeqCoords[k] = xSeqCoords[i];
					oneDirYSeqCoords[k] = ySeqCoords[i];
					oneDirOriginalIDs[k] = i;
					k++;
				}
				else Table.set("Directional_continuity",i,false);
			}
		}
		fPixN = k;
		IJ.log (fPixN + " direction-filtered pixels out of original " + seqPixN);
		if (filteredNorm){
			Array.getStatistics(oneDirOutRelDists,minOutRel,null,meanOutRel,null);
			for (i=0;i<fPixN;i++){
				oneDirOutRelDists[i] = abs(oneDirOutRelDists[i] - minOutRel);
				oneDirOutRelDistFMeans[i] = abs(oneDirOutRelDists[i] - meanOutRel);
				oneDirOutRelDistFMeanSqs[i] = pow(oneDirOutRelDistFMeans[i],2);
			}
		} 
		xSeqCoords = oneDirXSeqCoords;
		ySeqCoords = oneDirYSeqCoords;
		outPTPDists = oneDirOutPTPDists;
		outPTPDistTotals = oneDirOutPTPDistTotals;
		outPTPDistTotalEvals = oneDirOutPTPDistTotalEvals;
		if(angleOut){
			degreeOffsets = oneDirOutDegreeOffsets;
			degreeIncrements = oneDirOutDegreeIncrements;
		}
		seqPixN = fPixN;
		Table.update;
	}
	else if (sortByAngle){
		if (clockwise) Array.reverse(radianOffsets);
		Array.sort(radianOffsets,xSeqCoords,ySeqCoords,outPTPDists,outPTPDistTotals,outRelDists,outRelDistFMeans,outRelDistFMeanSqs);
	}
	if(gotScale){
		if (oneDirection){
			Array.getStatistics(oneDirOutRelDists, hStat_min, hStat_max, hStat_mean, hStat_stdDev);
			Array.getStatistics(oneDirOutRelDistFMeans, hStatFMean_min, hStatFMean_max, hStatFMean_mean, hStatFMean_stdDev);
			Array.getStatistics(oneDirOutRelDistFMeanSqs, hStatFMeanSq_min, hStatFMeanSq_max, hStatFMeanSq_mean, hStatFMeanSq_stdDev);
		}
		else {
			Array.getStatistics(outRelDists, hStat_min, hStat_max, hStat_mean, hStat_stdDev);
			Array.getStatistics(outRelDistFMeans, hStatFMean_min, hStatFMean_max, hStatFMean_mean, hStatFMean_stdDev);
			Array.getStatistics(outRelDistFMeanSqs, hStatFMeanSq_min, hStatFMeanSq_max, hStatFMeanSq_mean, hStatFMeanSq_stdDev);
		}
		hStats = "_________\n" + nTitle + " height statistics:\nmin = " + hStat_min + " " + unit + "\nmax = " + hStat_max + " " + unit;
		hStats += "\nrange = " + hStat_max-hStat_min + " " + unit +"\nmean = " + hStat_mean + " " + unit + "\nstd Dev = " + hStat_stdDev + " " + unit;
		hStats += "\n_________Deviation from Mean_________:\nmin = " + hStatFMean_min + " " + unit + "\nmax = " + hStatFMean_max + " " + unit  +"\nmean = " + hStatFMean_mean + " " + unit + "\nstd Dev = " + hStatFMean_stdDev + " " + unit;
		hStats += "\n_________The simple R values below do not have waviness extracted_____";
		hStats += "\nRa\(full length\) = " + hStatFMean_mean  + " " + unit + "\nRq\(full length\) = " + sqrt(hStatFMeanSq_mean)  + " " + unit +  "\n_________";		
		IJ.log(hStats);
		/* Note these are full wave amplitudes i.e. not mean subtracted */
		fAmps = Array.fourier(sNormRelDistances);
		fAmpsCol = "Fourier_amps";
		if(oneDirection) fAmpsCol += "_uni-dir.";
		if(gotScale) Table.setColumn(fAmpsCol, fAmps);
	}
	if (hMap){
		subSeqPixN = round(seqPixN/subSamN);
		newImage("tempHMap", "32-bit black", subSeqPixN, 1, 1);
		for(i=0,j=0,k=0; i<seqPixN; i++){
			if (j==subSamN){
				setPixel(k,0,outRelDists[i]);
				k++;
				j=0;
			}
			j++;
		}
		run("Size...", "width=" + subSeqPixN + " height=" + hMapN + " depth=1 interpolation=None");
		run("Set Scale...", "distance=" + subSeqPixN + " known=" + lRef + " pixel=1 unit=" + unit);
		run("Enhance Contrast...", "saturated=0"); /* required for viewable 32-bit Fiji image */
		mapT = nTitle + "_hMap";
		if(oneDirection) mapT += "_uni-dir.";
		if(sortByAngle) mapT += "_angle-sorted";
		rename(mapT);
		closeImageByTitle("tempHMap");
		if(saveTIFF) saveAs("Tiff");
	}
	if(filteredCSV){
		hideResultsAs("hiddenResults");
		if(!gotScale) unit = "pixels";
		Table.create("Results");
		rowID = Array.getSequence(fPixN);
		Table.setColumn("Seq_#",rowID);
		Table.setColumn("Original_#",oneDirOriginalIDs);
		Table.setColumn("Seq_coord_x",xSeqCoords);
		Table.setColumn("Seq_coord_y",ySeqCoords);
		Table.setColumn("Seq_incr\("+unit+"\)",outPTPDists);
		Table.setColumn("Seq_dist\("+unit+"\)",outPTPDistTotals);
		if(gotScale) Table.setColumn("Seq_dist\("+unit+"\)_NormToEval",outPTPDistTotalEvals); 
		if(angleOut){
			Table.setColumn("Angle Incr. \(degrees\)",degreeIncrements);
			Table.setColumn("Angle Offset \(degrees\)",degreeOffsets);
		} 
		Table.setColumn(distName + "_norm\("+unit+"\)",oneDirOutRelDists);
		Table.setColumn(distName + "_norm_from_Mean\("+unit+"\)",oneDirOutRelDistFMeans);
		Table.setColumn(distName + "_norm_from_Mean^2\("+unit+"^2\)",oneDirOutRelDistFMeanSqs);
		tCSV1 = nTitle + "_directional_outputCSV";
		outputCSVPath = dir + tCSV1 +".csv";
		updateResults();
		if (revertCoords){
			coords = newArray("Seq_coord_x","Seq_coord_y");
			columnOperation(coords,coords,"-",safeMargin);
		}
		if(File.exists(outputCSVPath)){
			 if(getBoolean("Overwrite " + tCSV1 +".csv?")) saveAs("Results", outputCSVPath);
		}
		else saveAs("Results", outputCSVPath);
		run("Close");
		restoreResultsFrom("hiddenResults");
		if(filteredOverlay && isOpen(tempID)){
			selectImage(tempID);
			makeSelection("polyline", xSeqCoords, ySeqCoords);
			Roi.setName("Filter coordinates");
			Overlay.addSelection(filteredOverlayCol, 1);
			run("Select None");
			nTitle += "+" + "filtered";
			rename(nTitle);
		}
	}
	if(isOpen(tempID) && unsequencedOverlay){
		selectImage(tempID);
		getRawStatistics(nPixels, meanPx, minPx, maxPx);
		if (minPx==0){
			selectWindow(nTitle);
			run("Create Selection");
			pArea = getValue("Area raw");
			IJ.log("Warning: " + pArea + " non-Sequenced pixels\n____");
			highlightS = minOf(4,maxOf(1,(imageW+imageH)/400));
			run("Enlarge...", "enlarge=&highlightS pixel");
			Roi.setName("Non-sequenced pixels");
			Overlay.addSelection(unsequencedOverlayColor, highlightS);
			nTitle += "+unsequenced_pxls";
			rename(nTitle);
			run("Select None");
			keepPixelSequence = true;
		}
		else if(!diagnostics) close(tempID);
	}
	if(expCanvas){
		if (revertCanvas){
			if(isOpen(nTitle)){
				selectWindow(nTitle);
				run("Canvas Size...", "width=&oImageW height=&oImageH position=Center");
			}
			if (startsWith(refLength,"Median") || smoothKeep){
				if (isOpen(medianT)){
					selectWindow(medianT);
					run("Canvas Size...", "width=&oImageW height=&oImageH position=Center");
				}
			}
		}
		if (revertCoords){
			selectWindow("Results");
			coords = newArray("Seq_coord_x","Seq_coord_y");
			columnOperation(coords,coords,"-",safeMargin);
		}
	}
	if (!diagnostics){
		closeImageByTitle(refLTitle);
		if(!keepPixelSequence) closeImageByTitle(nTtitle);
	}
	// else selectWindow(oTitle);
	setBatchMode("exit and display");
	exit();
	/* 
	End of unraveling macro
	*/
/*
	Color Functions
*/
	function getColorArrayFromColorName(colorName) {
		/* v180828 added Fluorescent Colors
		   v181017-8 added off-white and off-black for use in gif transparency and also added safe exit if no color match found
		   v191211 added Cyan
		   v211022 all names lower-case, all spaces to underscores v220225 Added more hash value comments as a reference v220706 restores missing magenta
		   REQUIRES restoreExit function.  57 Colors v230130 Added more descriptions and modified order
		*/
		if (colorName == "white") cA = newArray(255,255,255);
		else if (colorName == "black") cA = newArray(0,0,0);
		else if (colorName == "off-white") cA = newArray(245,245,245);
		else if (colorName == "off-black") cA = newArray(10,10,10);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "off-black") cA = newArray(10,10,10);
		else if (colorName == "light_gray") cA = newArray(200,200,200);
		else if (colorName == "gray") cA = newArray(127,127,127);
		else if (colorName == "dark_gray") cA = newArray(51,51,51);
		else if (colorName == "red") cA = newArray(255,0,0);
		else if (colorName == "green") cA = newArray(0,255,0); /* #00FF00 AKA Lime green */
		else if (colorName == "blue") cA = newArray(0,0,255);
		else if (colorName == "cyan") cA = newArray(0, 255, 255);
		else if (colorName == "yellow") cA = newArray(255,255,0);
		else if (colorName == "magenta") cA = newArray(255,0,255); /* #FF00FF */
		else if (colorName == "pink") cA = newArray(255, 192, 203);
		else if (colorName == "violet") cA = newArray(127,0,255);
		else if (colorName == "orange") cA = newArray(255, 165, 0);
		else if (colorName == "garnet") cA = newArray(120,47,64); /* #782F40 */
		else if (colorName == "gold") cA = newArray(206,184,136); /* #CEB888 */
		else if (colorName == "aqua_modern") cA = newArray(75,172,198); /* #4bacc6 AKA "Viking" aqua */
		else if (colorName == "blue_accent_modern") cA = newArray(79,129,189); /* #4f81bd */
		else if (colorName == "blue_dark_modern") cA = newArray(31,73,125); /* #1F497D */
		else if (colorName == "blue_honolulu") cA = newArray(0,118,182); /* Honolulu Blue #30076B6 */
		else if (colorName == "blue_modern") cA = newArray(58,93,174); /* #3a5dae */
		else if (colorName == "gray_modern") cA = newArray(83,86,90); /* bright gray #53565A */
		else if (colorName == "green_dark_modern") cA = newArray(121,133,65); /* Wasabi #798541 */
		else if (colorName == "green_modern") cA = newArray(155,187,89); /* #9bbb59 AKA "Chelsea Cucumber" */
		else if (colorName == "green_modern_accent") cA = newArray(214,228,187); /* #D6E4BB AKA "Gin" */
		else if (colorName == "green_spring_accent") cA = newArray(0,255,102); /* #00FF66 AKA "Spring Green" */
		else if (colorName == "orange_modern") cA = newArray(247,150,70); /* #f79646 tan hide, light orange */
		else if (colorName == "pink_modern") cA = newArray(255,105,180); /* hot pink #ff69b4 */
		else if (colorName == "purple_modern") cA = newArray(128,100,162); /* blue-magenta, purple paradise #8064A2 */
		else if (colorName == "jazzberry_jam") cA = newArray(165,11,94);
		else if (colorName == "red_n_modern") cA = newArray(227,24,55);
		else if (colorName == "red_modern") cA = newArray(192,80,77);
		else if (colorName == "tan_modern") cA = newArray(238,236,225);
		else if (colorName == "violet_modern") cA = newArray(76,65,132);
		else if (colorName == "yellow_modern") cA = newArray(247,238,69);
		/* Fluorescent Colors https://www.w3schools.com/colors/colors_crayola.asp */
		else if (colorName == "radical_red") cA = newArray(255,53,94);			/* #FF355E */
		else if (colorName == "wild_watermelon") cA = newArray(253,91,120);		/* #FD5B78 */
		else if (colorName == "shocking_pink") cA = newArray(255,110,255);		/* #FF6EFF Ultra Pink */
		else if (colorName == "razzle_dazzle_rose") cA = newArray(238,52,210); 	/* #EE34D2 */
		else if (colorName == "hot_magenta") cA = newArray(255,0,204);			/* #FF00CC AKA Purple Pizzazz */
		else if (colorName == "outrageous_orange") cA = newArray(255,96,55);	/* #FF6037 */
		else if (colorName == "supernova_orange") cA = newArray(255,191,63);	/* FFBF3F Supernova Neon Orange*/
		else if (colorName == "sunglow") cA = newArray(255,204,51); 			/* #FFCC33 */
		else if (colorName == "neon_carrot") cA = newArray(255,153,51);			/* #FF9933 */
		else if (colorName == "atomic_tangerine") cA = newArray(255,153,102);	/* #FF9966 */
		else if (colorName == "laser_lemon") cA = newArray(255,255,102); 		/* #FFFF66 "Unmellow Yellow" */
		else if (colorName == "electric_lime") cA = newArray(204,255,0); 		/* #CCFF00 */
		else if (colorName == "screamin'_green") cA = newArray(102,255,102); 	/* #66FF66 */
		else if (colorName == "magic_mint") cA = newArray(170,240,209); 		/* #AAF0D1 */
		else if (colorName == "blizzard_blue") cA = newArray(80,191,230); 		/* #50BFE6 Malibu */
		else if (colorName == "dodger_blue") cA = newArray(9,159,255);			/* #099FFF Dodger Neon Blue */
		else restoreExit("No color match to " + colorName);
		return cA;
	}
	function setBackgroundFromColorName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setBackgroundColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	function setColorFromColorName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	function setForegroundColorFromName(colorName) {
		colorArray = getColorArrayFromColorName(colorName);
		setForegroundColor(colorArray[0], colorArray[1], colorArray[2]);
	}
	/* Hex conversion below adapted from T.Ferreira, 20010.01 https://imagej.net/doku.php?id=macro:rgbtohex */
	function pad(n) {
	  /* This version by Tiago Ferreira 6/6/2022 eliminates the toString macro function */
	  if (lengthOf(n)==1) n= "0"+n; return n;
	  if (lengthOf(""+n)==1) n= "0"+n; return n;
	}
	function getHexColorFromRGBArray(colorNameString) {
		colorArray = getColorArrayFromColorName(colorNameString);
		 r = toHex(colorArray[0]); g = toHex(colorArray[1]); b = toHex(colorArray[2]);
		 hexName= "#" + ""+pad(r) + ""+pad(g) + ""+pad(b);
		 return hexName;
	}
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
	function hideResultsAs(deactivatedResults) {
		if (isOpen("Results")) {  /* This swapping of tables does not increase run time significantly */
			selectWindow("Results");
			IJ.renameResults(deactivatedResults);
		}
	}
	function indexOfArray(array, value, default) {
		/* v190423 Adds "default" parameter (use -1 for backwards compatibility). Returns only first found value */
		index = default;
		for (i=0; i<lengthOf(array); i++){
			if (array[i]==value) {
				index = i;
				i = lengthOf(array);
			}
		}
	  return index;
	}
	function restoreResultsFrom(deactivatedResults) {
		/* v230214	extra close check */
		if (isOpen(deactivatedResults)) {
			selectWindow(deactivatedResults);
			IJ.renameResults("Results");
		}
		// if (isOpen(deactivatedResults)) close(deactivatedResults);
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
	function columnOperation(columnNames,newColumnNames,operator,operand){
		lFunction = "columnOperation_v230306";
		coords = newArray("Seq_coord_x","Seq_coord_y");
		if (columnNames.length!=newColumnNames.length) exit(lFunction + ": Unequal column name array lengths");
		for(i=0;i<columnNames.length;i++){
			formula = "" + columnNames[i] + operator + operand;
			mCode = newColumnNames[i] + "=" + formula;
			Table.applyMacro(mCode);
		}
		updateResults();
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