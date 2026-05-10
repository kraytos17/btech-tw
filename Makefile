report:
	pdflatex -shell-escape report.tex
	pdflatex -shell-escape report.tex

slides:
	pdflatex -shell-escape slides.tex
	pdflatex -shell-escape slides.tex

beamer:
	pdflatex -shell-escape final_slides.tex
	pdflatex -shell-escape final_slides.tex

progress:
	pdflatex -shell-escape progress.tex
	pdflatex -shell-escape progress.tex

final:
	pdflatex -shell-escape final_report.tex
	bibtex final_report || true
	pdflatex -shell-escape final_report.tex
	pdflatex -shell-escape final_report.tex

clean:
	rm -f *.aux *.log *.toc *.out *.bbl *.blg *.nav *.snm *.vrb *.bbl *.blg *.lof *.lot
