#include "Spline.hpp"
#include <stdexcept>
#include <iostream>

using std::vector;
using std::string;

namespace tr { namespace util {

Spline
Spline::ident() {
    Spline c;
    c.addKnot(Knot(0, 0));
    c.addKnot(Knot(1, 1));
    return c;
}

bool
operator==(const Spline& l, const Spline& r) {
    return l.knots() == r.knots();
}

bool
operator!=(const Spline& l, const Spline& r) {
    return l.knots() != r.knots();
}

void
Spline::calcSecondDerivatives() const {
    if (frozen)
        return;

    if (knots_.size() < 2)
        throw std::runtime_error("Spline needs at least two knots");

    bool pointsOverlap = true;
    while (pointsOverlap) {
        pointsOverlap = false;
        KnotVector& ncKnots = const_cast<KnotVector&>(knots_);
        std::sort(ncKnots.begin(), ncKnots.end());
        for (KnotVector::iterator k = ncKnots.begin(), ke = ncKnots.end() - 1;
          k != ke; ++k)
        {
            KnotVector::iterator nk = k + 1;
            if (k->x == nk->x) {
                pointsOverlap = true;
                if (nk->x == 0)
                    nk->x = std::numeric_limits<double>::epsilon();
                else
                    nk->x += nk->x * std::numeric_limits<double>::epsilon();
            }
        }
    }

    const size_t size = knots_.size();

    derivs.resize(size, 0.0);
    vector<double> u(size, 0.0);

    for (size_t i = 1; i < size - 1; ++i) {
        double sig = (knots_[i].x - knots_[i - 1].x) /
          (knots_[i + 1].x - knots_[i - 1].x);
        double p = sig * derivs[i - 1] + 2.0;
        derivs[i] = (sig - 1.0) / p;
        u[i] = (knots_[i + 1].y - knots_[i].y) /
            (knots_[i + 1].x - knots_[i].x) -
          (knots_[i].y - knots_[i - 1].y) /
            (knots_[i].x - knots_[i - 1].x);
        u[i] = (6.0 * u[i] /
          (knots_[i + 1].x - knots_[i - 1].x) - sig * u[i - 1]) / p;
    }

    derivs.back() = u.back() = 0.0;
    for (int i = (int)size - 2; 0 <= i; --i) {
        derivs[i] = derivs[i] * derivs[i + 1] + u[i];
    }

    frozen = true;
}

double
Spline::interpolate(size_t i, double xVal) const {
    const double h = knots_[i + 1].x - knots_[i].x;
    const double a = (knots_[i + 1].x - xVal) / h;
    const double b = (xVal - knots_[i].x) / h;

    return a * knots_[i].y + b * knots_[i + 1].y +
      ((a * a * a - a) * derivs[i] + (b * b * b - b) * derivs[i + 1]) *
      (h * h) / 6.0;
}

double
Spline::operator()(double xVal) const {
    if (!frozen)
        calcSecondDerivatives();

    if (xVal <= knots_.front().x) return knots_.front().y;
    if (xVal >= knots_.back().x) return knots_.back().y;

    size_t i = 0;
    for ( ; i < knots_.size() - 1; ++i) {
        if (knots_[i].x <= xVal && knots_[i + 1].x >= xVal)
            return interpolate(i, xVal);
    }

    return interpolate(i, xVal);
}

void
Spline::addKnot(const Knot& k) {
    knots_.push_back(k);
    frozen = false;
}

void
Spline::clear() {
    knots_.clear();
    frozen = false;
}

std::ostream&
operator<<(std::ostream& s, const Spline::Knot& k) {
    return s << k.x << "," << k.y;
}

std::ostream&
operator<<(std::ostream& s, const Spline& k) {
    int count = 0;
    for (Spline::KnotVector::const_iterator i = k.knots_.begin(),
      e = k.knots_.end(); i != e; ++i) {
        if (++count > 1) s << ";";
        s << *i;
    }
    return s;
}

} }

extern "C" {

void TRSplineAddKnot(void* spline, double x, double y) {
    tr::util::Spline* s = static_cast<tr::util::Spline*>(spline);
    s->addKnot(tr::util::Spline::Knot(x, y));
}

void TRSplineInitializeWithIdentity(void* spline) {
    tr::util::Spline* s = static_cast<tr::util::Spline*>(spline);
    s->addKnot(tr::util::Spline::Knot(0, 0));
    s->addKnot(tr::util::Spline::Knot(1, 1));
}

}
