# Normalizing cubemap generator

Normalizing cubemaps are a lossy optimization technique [suggested by nVidia](http://http.developer.nvidia.com/CgTutorial/cg_tutorial_chapter08.html) for normalize() calls on the fragment shader.  

A typical implementation of normalize() involves the following operations.

    float3 normalize(float3 v)
    {
        return rsqrt(dot(v,v))*v;
    }
    
On the vertex shader this is negligible, but for repeated calls per fragment the square roots and multiplications add up significantly.

Normalizing cubemaps, range-compressed cube maps with color-encoded normals, simplify vector normalization to a texCUBE call, a subtraction and a multiplication.  

In a shader, this alternative normalize would look like this:  

    inline float3 expand(float3 vec){
        return (vec - 0.5) * 2;
    }
    inline float3 normalizeCube(float3 vec){
        return expand(texCUBE(_NormalizingCube, vec).xyz);
    }

The cubemap should not be filtered in any way. For calculating diffuse such as Oren-Nayar I've found maps as small as 32x32 can be sufficient.  

Note that YMMV when it comes to artifacting using this approach, depending on your cubemap resolution and the problem you are solving. Use prudently.

I was unable to find a simple generator for creating these textures, so writing my own I decided to make it a generic tool. Hopefully it will be of use to others.  

### Usage

* **Neko**  
  ```neko normcubegen -size 512 -out outputdirectorypath```
* **Cpp**  
  ```normcubegen -size 512 -out outputdirectorypath```
  
Either argument is optional. Size defaults to 128, and the default output directory is the current directory.  
The result is 6 png RGB textures that should hopefully be intuitively named for use.

### Building

1. [Download and install Haxe 3](http://haxe.org/download/)
2. From a terminal, run ```haxelib install format```  
  If you want to build a native executable, also run ```haxelib install hxcpp```
3. From the repository directory, run either ```haxe build_neko.hxml``` or ```haxe build_cpp.hxml```  
  The executable or neko binary will now be placed in the bin/ directory
  
#### Neko or CPP?
Cpp takes longer to build but runs significantly faster for larger textures almost by a factor of 10. The cpp executable can also be distributed to users without neko installed.  
Neko is simpler to build but runs slow and requires a neko install to run.
