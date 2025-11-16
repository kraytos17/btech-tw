all:
	pdflatex -shell-escape report.tex
	pdflatex -shell-escape report.tex
	pdflatex -shell-escape report.tex

clean:
	rm -f *.aux *.log *.toc *.out *.bbl *.blg