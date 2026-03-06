report:
	pdflatex -shell-escape report.tex
	pdflatex -shell-escape report.tex
	pdflatex -shell-escape report.tex

slides:
	pdflatex -shell-escape slides.tex
	pdflatex -shell-escape slides.tex

progress:
	pdflatex -shell-escape progress.tex
	pdflatex -shell-escape progress.tex

clean:
	rm -f *.aux *.log *.toc *.out *.bbl *.blg *.nav *.snm *.vrb
