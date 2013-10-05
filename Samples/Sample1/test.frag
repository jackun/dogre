#version 120
    
uniform sampler2D texMap;

varying vec4 colour;
varying vec4 uv;

/*
  Basic fragment program using texture and diffuse colour.
*/
void main()
{
    gl_FragColor = 1.0-texture2D(texMap, uv.xy);
}
