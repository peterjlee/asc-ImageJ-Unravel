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
*/
	macroL = "Unravel_interface_v230211b.ijm";
	setBatchMode(true);
	oTitle = getTitle;
	oID = getImageID();
	getPixelSize(unit, pixelWidth, pixelHeight);
	lcf=(pixelWidth+pixelHeight)/2; /* ---> add here the side size of 1 pixel in the new calibrated units (e.g. lcf=5, if 1 pixels is 5mm) <--- */
	nTitle = stripKnownExtensionFromString(oTitle);
	nTitle += "_unrav";
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
	linity = pPerimeter/pArea;
	run("Select None");
	run("Fill Holes");
	getRawStatistics(nPixels, meanPx, minPx, maxPx);
	pFArea = (maxPx/meanPx-1)*nPixels;
	run("Undo");
	if (linity>0.95){
		if (pFArea/pArea>=1.1) objectType = "Continuous_outline";
		else if (oSolidity==1){
			if (oAngle<45) objectType = "Horizontal_line";
			else objectType = "Vertical_line";
		}
	} 
	else if (pFArea/pArea<1.1 || oSolidity>0.5)	objectType = "Solid_object";
	else objectType = "Something_else";
	if (objectType=="Solid_object") safeBuffer = round(pPerimeter/20);
	else {
		run("Create Selection");
		setOption("BlackBackground", false);
		run("Skeletonize");
		pPerimeter = getValue("Perim. raw");
		pArea = getValue("Area raw");
		run("Undo");
		safeBuffer = round(pArea/20);
		run("Select None");
	}
	if (safeBuffer>oImageW && safeBuffer>oImageH) showMessage("Problem with safeBuffer size \(" + safeBuffer + "\), minimum border space = " + minBorder);
	/* Make sure canvas is large enough to accommodate any smoothing or fits */
	if (minX<safeBuffer/2 || (oImageW-(minX+widthS))<safeBuffer/2) newWidth = safeBuffer+oImageW;
	else newWidth = oImageW;
	if (minY<safeBuffer/2 || (oImageH-(minY+heightS))<safeBuffer/2) newHeight = safeBuffer+oImageH;
	else newHeight = oImageH;
	if (newHeight!=oImageH || newWidth!=oImageW)	expCanvas = true; /* Could use as a contraction flag for a future option */
	else expCanvas = false;
	if (expCanvas) run("Canvas Size...", "width=&newWidth height=&newHeight position=Center");
	run("Create Selection");
	pX = getValue("X raw");
	pY = getValue("Y raw");
	run("Select None");
	getDimensions(imageW, imageH, oChannels, oSlices, oFrames);
	objectTypes = newArray("Continuous_outline","Solid_object","Horizontal_line","Vertical_line","Something_else");
	setBatchMode("exit and display");
	Dialog.create("Unraveling options 1: \(" + macroL + "\)");
		Dialog.addMessage("This macro currently only works on individual objects of the types listed below:");
		if(oChannels+oSlices+oFrames!=3) Dialog.addMessage("Warning: This macro has only been tested on single slice-frame-channel images",12,"red");
		Dialog.addRadioButtonGroup("Object type:",objectTypes,objectTypes.length,1,objectType);
		Dialog.addMessage("Identified object type: " + objectType+ "  from:\nTotal pixels: " + pArea + "\nBlack pixels after fill: " + pFArea + "\nAspect ratio: " + oAR + "\nPerimeter: " + pPerimeter + " pixels\nSolidity: " + oSolidity + "\nAngle: " + oAngle);
	Dialog.show;
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
		Dialog.addRadioButtonGroup("Output evaluation length \(used for map scale\):",refLengths,refLengths.length,1,refLengths[defRef]);
		if (startsWith(objectType, "Solid")) defSmoothN = minOf(1000,round(pPerimeter/50)); /* median smoothing limited to max of 1000 */
		else defSmoothN = minOf(1000,round(pArea/50)); /* median smoothing limited to max of 1000 */
		if (!endsWith(objectType,"_line")){
			Dialog.addCheckbox("Create median smoothed object \(i.e. physical waviness\)",false);
			Dialog.addNumber("Radius for median smoothing \(mean filter method\)",defSmoothN,0,4,"pixels \(max 1000\)");
			if (startsWith(objectType, "Solid")) mText = "Default median radius of " + defSmoothN + " pixels based on 2% of original perimeter \(" + pPerimeter + " pixels\)";
			else mText = "Default median radius of " + defSmoothN + " pixels based on 2% of original perimeter \(" + pArea + " pixels\)";
			if (defSmoothN==100) mText += ", limited to a maximum of 1000";
			Dialog.addMessage(mText);
		}
		else {
			Dialog.addNumber("Sub-sample interval for spline",defSmoothN,0,4,"pixels");
			Dialog.addMessage("Default interval of " + defSmoothN + " pixels based on 2% of original pixels in line\n");
		}
		/* Fewer outline-skeletonized pixels will be missed from the unravel sequence, so skeletonizing the line/outline is the default setting: */
		Dialog.addCheckbox("Skeletonize outline/interface line \(could remove significant pixels\)",true); /* removes redundant pixels . . . but are they? */
		Dialog.addCheckbox("Create pseudo-height map from interface",true);
		Dialog.addCheckbox("Diagnostics",false);
	Dialog.show;
		refLength = Dialog.getRadioButton();
		if (!endsWith(objectType,"_line")) smoothKeep = Dialog.getCheckbox();
		smoothN = minOf(1000,Dialog.getNumber());
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
	else startCoordOptions = Array.concat("Left  pixel \("+leftX+","+leftY+"\)","Top pixel \("+topX+","+topY+"\)",startCoordOptions);
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
		Dialog.addCheckbox("Keep image showing pixel sequence and spline fit",true);
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
	xDistancesTotal = newArray();
	xDistancesTotal[0] = 0;
	if(lcf!=1){
		xSDistancesTotal = newArray();
		xSDistancesTotal[0] = 0;
	}
	for (i=1;i<seqPixN;i++) xDistancesTotal[i] = xDistancesTotal[i-1] + xDistances[i];
	if(lcf!=1) for (i=1;i<seqPixN;i++) xSDistancesTotal[i] = lcf * xDistancesTotal[i];
	Array.getStatistics(xDistancesTotal, xDistancesTotal_min, xDistancesTotal_max, xDistancesTotal_mean, xDistancesTotal_stdDev);
	/* The following section provides an estimate of the total evaluation length */
	selectWindow(refLTitle);
	if(refLength=="Total_pixel-pixel_length") lRef = xDistancesTotal_max;
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
			if(lcf!=1) lRef*= lcf;
		}
		run("Select None");
		selectWindow(nTitle);
		run("Restore Selection");
		Overlay.addSelection("#66FF66", minOf(1,maxOf(2,(imageW+imageH)/400)));
		nTitle += "+" + refLength;
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
		Overlay.addSelection("#66FF66", minOf(1,maxOf(2,(imageW+imageH)/400)));
		nTitle += "+" + refLength;
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
			Dialog.addString("Table compatible name for distance to reference \(i.e. 'Height'\)","Height",10);
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
	radianAngles = newArray();
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
	if(lcf!=1){
		sNormRelDistances = newArray();
		sNormRelDistSqs = newArray();
		for (i=0;i<seqPixN;i++){
			sNormRelDistances[i] = lcf * normRelDistances[i];
			sNormRelDistSqs[i] = pow(sNormRelDistances[i],2);
		}
	}
	Table.setColumn("Seq_coord_x", xSeqCoords);
	Table.setColumn("Seq_coord_y", ySeqCoords);
	Table.setColumn("Seq_dist\(px\)", xDistancesTotal);
	if(lcf!=1) Table.setColumn("Seq_dist\("+unit+"\)", xSDistancesTotal);
	if(continuous){
		Table.setColumn(distName + "\(px\)", relDistances);
		Table.setColumn(distName + "_norm\(px\)", normRelDistances);
		if(lcf!=1){
			Table.setColumn(distName + "_norm\("+unit+"\)", sNormRelDistances);
			Table.setColumn(distName + "_norm^2\("+unit+"^2\)",sNormRelDistSqs);
		}
		else Table.setColumn(distName + "_norm^2",normRelDistSqs);
		if(angleOut){
			Table.setColumn("Angle \(radians\)",radianAngles);
			Table.setColumn("Angle Offset \(radians\)",radianOffsets);
			Table.setColumn("Angle Offset \(degrees\)",degreeOffsets);
			Table.setColumn("Angle Incr. \(radians\)",radianIncrements);
			Table.setColumn("Angle Incr. \(degrees\)",degreeIncrements);
		}
	}
	else {
		Table.setColumn(distName + "\(px\)", relDistances);
		Table.setColumn(distName + "_norm\(px\)", normRelDistances);
		if(lcf!=1){
			Table.setColumn(distName + "_norm\("+unit+"\)", sNormRelDistances);
			Table.setColumn(distName + "_norm^2\("+unit+"^2\)", sNormRelDistSqs);
		}
		else Table.setColumn(distName + "_norm^2",normRelDistSqs);
	}
	clockwise = clockwiseIncr;
	Dialog.create("Output and Height map options: " + macroL);
		Dialog.addMessage(seqPixN + " interface pixels found");
		Dialog.addCheckbox("Filter out reverse direction(no re-entrant angles)?",true);
		if (hMap){
			Dialog.addNumber("Evaluation length \(from " + refLength + "\) to embed as horizontal scale:",lRef,10,14,unit);
			Dialog.addNumber("Repeated lines to create 2D height map:",maxOf(50,round(seqPixN/10)),0,4,"rows");
			Dialog.addNumber("Sub-sample measurements \(1 = none\):",maxOf(1,round(seqPixN/4000)),0,10,"");
			Dialog.addCheckbox("Map should be saved as uncompressed TIFF; go ahead?",true);
		}
		if (angleOut){
			Dialog.addCheckbox("Sort data by offset angle (not useful if direction filtered)?",false);
			if(clockwiseIncr) Dialog.addCheckbox("Leave as clockwise direction \(clockwise from analysis\)?",clockwiseIncr);
			else Dialog.addCheckbox("Reverse to clockwise \(anti-clockwise from analysis\)?",clockwiseIncr);
		}
	Dialog.show();
		oneDirection = Dialog.getCheckbox();
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
	if(lcf!=1) outRelDists = sNormRelDistances;
	else outRelDists = normRelDistances;
	if (oneDirection) {
		oneDirOutRelDists = newArray(outRelDists[0],0);
		if(lcf!=1) oneDirOutRelDistsSq = newArray();
		if(clockwise){
			for(i=0,angle=360,k=0; i<seqPixN; i++){
				if(degreeOffsets[i]<angle){
					if(i>0) angle = degreeOffsets[i];
					oneDirOutRelDists[k] = outRelDists[i];
					if(lcf!=1) oneDirOutRelDistsSq[k] = sNormRelDistSqs[i];
					k++;
				}
			}
		}
		else {
			for(i=0,angle=-1,k=0; i<seqPixN; i++){
				if(degreeOffsets[i]>angle){
					if(i>0) angle = degreeOffsets[i];
					oneDirOutRelDists[k] = outRelDists[i];
					if(lcf!=1) oneDirOutRelDistsSq[k] = sNormRelDistSqs[i];
					k++;
				}
			}
		}
		fPixN = oneDirOutRelDists.length;
		IJ.log (fPixN + " direction-filtered pixels out of original " + seqPixN);
		outRelDists = oneDirOutRelDists;
		if(lcf!=1) sNormRelDistSqs = oneDirOutRelDistsSq;
		seqPixN = fPixN;
	}
	else if (sortByAngle){
		if (clockwise) Array.reverse(radianOffsets);
		Array.sort(radianOffsets,outRelDists,sNormRelDistSqs);
	}
	if(lcf!=1){
		Array.getStatistics(outRelDists, hStat_min, hStat_max, hStat_mean, hStat_stdDev);
		Array.getStatistics(sNormRelDistSqs, null, null, hSq_mean, null);
		IJ.log("_________\n" + nTitle + " height statistics:\nmin = " + hStat_min + " " + unit + "\nmax = " + hStat_max + " " + unit + "\nrange = " + hStat_max-hStat_min + " " + unit +"\nmean = " + hStat_mean + " " + unit + "\nstd Dev = " + hStat_stdDev + " " + unit + "\nRa\(full length) = " + hStat_mean  + " " + unit + "\nRq\(full length\) = " + sqrt(hSq_mean)  + " " + unit +  "\n_________");
		fAmps = Array.fourier(sNormRelDistances);
		fAmpsCol = "Fourier_amps";
		if(oneDirection) fAmpsCol += "_uni-dir.";
		if(lcf!=1) Table.setColumn(fAmpsCol, fAmps);
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
	selectImage(tempID);
	getRawStatistics(nPixels, meanPx, minPx, maxPx);
	if (minPx==0){
		selectWindow(nTitle);
		run("Create Selection");
		pArea = getValue("Area raw");
		IJ.log("Warning: " + pArea + " non-Sequenced pixels\n____");
		highlightS = minOf(4,maxOf(1,(imageW+imageH)/400));
		run("Enlarge...", "enlarge=&highlightS pixel");
		Overlay.addSelection("#099FFF", highlightS);
		nTitle += "+unsequenced_pxls";
		rename(nTitle);
		run("Select None");
		keepPixelSequence = true;
	}
	else if(!diagnostics) close(tempID);
	if (!diagnostics){
		closeImageByTitle(refLTitle);
		if(!keepPixelSequence) closeImageByTitle(nTtitle);
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