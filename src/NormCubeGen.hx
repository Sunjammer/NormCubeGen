package;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesOutput;
import haxe.io.Output;
import haxe.Timer;
import format.png.Writer;
import format.png.Data;
import format.png.Tools;

#if (cpp||neko)
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
#end

#if cpp
import cpp.Lib;
import cpp.vm.Thread;
#elseif neko
import neko.Lib;
#end

/**
 * Generate 6-sided range compressed normalization RGB cubemap as 6 png images.
 * Usage: "normcubegen -size 128 -out ."
 * 		Arguments:
 *			-size 128 (The desired texture size per face. Default is 128.)
 *  		-out path (The desired output directory. Default is current dir.)
 * Normalizing cubemaps are described in http://http.developer.nvidia.com/CgTutorial/cg_tutorial_chapter08.html
 * @author Andreas Rønning
 */

class V3 {
	public var x:Float;
	public var y:Float;
	public var z:Float;
	public function new(x = 0.0, y = 0.0, z = 0.0) {
		this.x = x;
		this.y = y;
		this.z = z;
	}
	public function normalize() {
		var d = x * x + y * y + z * z; // x*x + y*y + z*z
		var sqrt = Math.sqrt(d);
		x /= sqrt;
		y /= sqrt;
		z /= sqrt;
	}
	public function rangeCompress() {
		normalize();
		x = (x + 1) * 0.5;
		y = (y + 1) * 0.5;
		z = (z + 1) * 0.5;
	}
	public function set(x:Float, y:Float, z:Float) {
		this.x = x;
		this.y = y;
		this.z = z;
	}
}

class NormCubeGen 
{
	
	static function genFace(idx:Int, size:Int, halfsize:Float, offset:Float) {
		#if cpp
		var main:Thread = Thread.readMessage(true);
		#end
		var data = new BytesOutput();
		var vec = new V3();
		var progress = 0.0;
		var totalPixels = size * size;
		var time = Timer.stamp();
		for (y in 0...size)
		{
			for (x in 0...size)
			{
				switch (idx)
				{
					default: vec.set( halfsize, y + offset - halfsize, -(x + offset - halfsize));
					case 1: vec.set(-halfsize, y + offset - halfsize, x + offset - halfsize );
					case 2: vec.set( x + offset - halfsize, -halfsize, y + offset - halfsize);
					case 3: vec.set( x + offset - halfsize, halfsize, -(y + offset - halfsize));
					case 4: vec.set( x + offset - halfsize, y + offset - halfsize, halfsize);
					case 5: vec.set( -( x + offset - halfsize), y + offset - halfsize, -halfsize);
				}
				
				vec.rangeCompress();
				
				data.writeByte(Std.int(vec.x * 255));
				data.writeByte(Std.int(vec.y * 255));
				data.writeByte(Std.int(vec.z * 255));
				
				progress = (y * size + x) / totalPixels;
			}
		}
		
		var pngData = Tools.buildRGB(size, size, data.getBytes());
		
		var facing = switch(idx) {
			default: "negX";
			case 1: "posX";
			case 2: "posY";
			case 3: "negY";
			case 4: "posZ";
			case 5: "negZ";
		}
		var name = "NormalizeCube_" + facing + ".png";
		
		#if cpp
		main.sendMessage( { name:name, data:pngData } );
		#elseif neko
		return { name:name, data:pngData };
		#end
	}
	
	static inline function println(o) {
		Lib.println(o);
	}
	
	static function main() 
	{
		var faceSize = 128;
		var args = Sys.args();
		var outPath = ".";
		while (args.length > 0) {
			var a = args.shift();
			var b = args.shift();
			switch(a) {
				case "-size":
					faceSize = Std.parseInt(b);
					if (faceSize == 0) {
						println("Invalid size argument (Must be int higher than 0)");
						return;
					}
				case "-out":
					outPath = b;
				default:
					println("Unrecognized argument '" + a + "'");
					return;
			}
		}
		var offset = 0.5;
		var halfsize = faceSize * 0.5;
		#if cpp
		var workers = [];
		#elseif neko
		var faces = [];
		#end
		
		var time = Timer.stamp();
		
		for (face in 0...6)
		{
			#if cpp
			var worker = Thread.create(genFace.bind(face, faceSize, halfsize, offset));
			worker.sendMessage(Thread.current());
			workers.push(worker);
			#elseif neko
			faces.push(genFace(face, faceSize, halfsize, offset));
			#end
		}
		
		if (!FileSystem.exists(outPath)) {
			FileSystem.createDirectory(outPath);
		}
		
		#if cpp
		while(workers.length>0){
			var result = Thread.readMessage(true);
			var out = File.write(outPath+"/"+result.name, true);
			var w = new Writer(out);
			w.write(result.data);
			out.close();
			
			println("Created " + result.name);
			workers.pop();
		}
		#elseif neko
		for(f in faces){
			var out = File.write(outPath+"/"+f.name, true);
			var w = new Writer(out);
			w.write(f.data);
			out.close();
			
			println("Created " + f.name);
		}
		#end
		
		var delta = Timer.stamp() - time;
		
		println("Finished in " + delta + " seconds");

	}
	
}