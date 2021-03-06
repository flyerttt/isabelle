/*  Title:      Pure/Tools/news.scala
    Author:     Makarius

Support for the NEWS file.
*/

package isabelle


object NEWS
{
  /* generate HTML version */

  def generate_html()
  {
    val target = Path.explode("~~/doc")

    File.write(target + Path.explode("NEWS.html"),
      HTML.begin_document("NEWS") +
      "\n<div class=\"source\">\n<pre class=\"source\">" +
      HTML.output(Symbol.decode(File.read(Path.explode("~~/NEWS")))) +
      "</pre>\n" +
      HTML.end_document)

    for (font <- Path.split(Isabelle_System.getenv_strict("ISABELLE_FONTS")))
      File.copy(font, target)

    File.copy(Path.explode("~~/etc/isabelle.css"), target)
  }


  /* command line entry point */

  def main(args: Array[String])
  {
    Command_Line.tool0 { generate_html() }
  }
}
