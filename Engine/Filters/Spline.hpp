#ifndef TR_UTIL_SPLINE_HPP_INCLUDED
#define TR_UTIL_SPLINE_HPP_INCLUDED

#include <vector>
#include <iosfwd>

namespace tr { namespace util {

class Spline {
public:
    struct Knot {
        Knot(double x = 0.0, double y = 0.0) : x(x), y(y) {}
        template <typename T> Knot(const T& t) : x(t.x), y(t.y) {}
        Knot& operator/=(double v) { x /= v, y /= v; return *this; }
        Knot& operator*=(double v) { x *= v, y *= v; return *this; }
        double x, y;
    };

    typedef std::vector<Knot> KnotVector;

    Spline() : frozen(0) {}

    void addKnot(const Knot& k);
    void clear();

    double operator()(double xVal) const;

    const KnotVector& knots() const { return knots_; }

    static Spline ident();

private:

    double interpolate(size_t intervalIdx, double xVal) const;
    void calcSecondDerivatives() const;

    KnotVector knots_;
    mutable bool frozen;
    mutable std::vector<double> derivs;

    friend std::ostream& operator<<(std::ostream& s, const Spline& k);
};

inline bool operator<(const Spline::Knot& l, const Spline::Knot& r)
  { return l.x < r.x || (l.x == r.x && l.y < r.y); }

std::ostream& operator<<(std::ostream& s, const Spline::Knot& k);

inline Spline::Knot operator/(Spline::Knot k, double v) { return k /= v; }
inline Spline::Knot operator*(Spline::Knot k, double v) { return k *= v; }

inline bool operator==(const Spline::Knot& l, const Spline::Knot& r)
  { return l.x == r.x && l.y == r.y; }
inline bool operator!=(const Spline::Knot& l, const Spline::Knot& r)
  { return l.x != r.x || l.y != r.y; }

bool operator==(const Spline& l, const Spline& r);
bool operator!=(const Spline& l, const Spline& r);

} }

extern "C" {
void TRSplineAddKnot(void* spline, double x, double y);
void TRSplineInitializeWithIdentity(void* spline);
}

#endif
